#
# fluent-plugin-calyptia-monitoring
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'net/http'
require 'monitor'
require 'time'
require 'fluent/version'
require 'fluent/env'
require "fluent/plugin/input"
require "serverengine"
require_relative "calyptia_monitoring_ext"
require_relative "calyptia_monitoring_buffer_ext"
require_relative "calyptia_monitoring_calyptia_api_requester"

module Fluent
  module Plugin
    class CalyptiaMonitoringInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("calyptia_monitoring", self)

      class CreateAgentError < Fluent::ConfigError; end
      class UpdateAgentError < Fluent::ConfigError; end

      helpers :timer, :storage, :child_process

      RPC_CONFIG_DUMP_ENDPOINT = "/api/config.getDump".freeze
      DEFAULT_STORAGE_TYPE = 'local'
      DEFAULT_PENDING_METRICS_SIZE = 100
      UNPROCESSABLE_HTTP_ERRORS = [
        422, # Invalid Metrics
        410, # Agent Gone
        401, # Unauthorized
        400, # BadRequest
      ]

      config_section :cloud_monitoring, multi: false, required: true do
        desc 'The endpoint for Monitoring API HTTP request, e.g. http://example.com/api'
        config_param :endpoint, :string, default: "https://cloud-api.calyptia.com"
        desc 'The API KEY for Monitoring API HTTP request'
        config_param :api_key, :string, secret: true
        desc 'Emit monitoring values interval. (minimum interval is 30 seconds.)'
        config_param :rate, :time, default: 30
        desc 'Setup pending metrics capacity size'
        config_param :pending_metrics_size, :size, default: DEFAULT_PENDING_METRICS_SIZE
        desc 'Specify Fluentd config file path for RPC not to be available case'
        config_param :fluentd_conf_path, :string, default: nil
      end

      def multi_workers_ready?
        true
      end

      def initialize
        super
        @current_config = nil
        @monitor = Monitor.new
        @pending = []
      end

      def configure(conf)
        super

        config = conf.elements.select{|e| e.name == 'storage' }.first
        @storage_agent = storage_create(usage: 'calyptia_monitoring_agent', conf: config, default_type: DEFAULT_STORAGE_TYPE)
      end

      def get_current_config_from_rpc
        res = retrieve_config_from_rpc
        config = Yajl.load(res.body)["conf"]
        conf = Fluent::Config.parse(config, '(supervisor)', '(RPC)', true)
        confs = []
        conf.elements.select{|e| e.name == 'ROOT' }.first.elements.each{|e|
          confs << e.to_s
        }
        # Remove outer <ROOT> element
        confs.join
      end

      def get_masked_conf_from_conf_file
        return "" unless File.exist?(@cloud_monitoring.fluentd_conf_path) # check file existence.

        conf = ""
        callback = ->(status) {
          if status && status.success?
            #nop
          elsif status
            log.warn "config dumper exits with error code", prog: prog, status: status.exitstatus, signal: status.termsig
          else
            log.warn "config dumper unexpectedly exits without exit status", prog: prog
          end
        }
        spawn_command, arguments = if Fluent.windows?
                          [::ServerEngine.ruby_bin_path, File.join(File.dirname(__FILE__), "calyptia_config_dumper.rb")]
                        else
                          [File.join(File.dirname(__FILE__), "calyptia_config_dumper.rb")]
                        end

        retval = child_process_execute(:exec_calyptia_config_dumper, spawn_command, arguments: arguments, immediate: true,
                                       env: {"FLUENT_CONFIG_PATH" => @cloud_monitoring.fluentd_conf_path}, parallel: true, mode: [:read_with_stderr],
                                       on_exit_callback: callback) do |io|
          io.set_encoding(Encoding::ASCII_8BIT)
          conf = io.read
        end
        unless retval.nil?
          begin
            Timeout.timeout(10) do
              sleep 0.1 until !conf.empty?
            end
          rescue Timeout::Error
            log.warn "cannot retrive configuration contents on #{@cloud_monitoring.fluentd_conf_path} within 10 seconds."
          end
        end
        conf
      end

      def start
        super

        enabled_cmetrics = if system_config.metrics
                             system_config.metrics[:@type] == "cmetrics"
                           else
                             false
                           end
        raise Fluent::ConfigError, "cmetrics plugin should be used to collect metrics on Calyptia Cloud" unless enabled_cmetrics
        @monitor_agent = Fluent::Plugin::CalyptiaMonitoringExtInput.new
        @monitor_agent_buffer = Fluent::Plugin::CalyptiaMonitoringBufferExtInput.new
        @api_requester = Fluent::Plugin::CalyptiaAPI::Requester.new(@cloud_monitoring.endpoint,
                                                                    @cloud_monitoring.api_key,
                                                                    log,
                                                                    fluentd_worker_id)
        @current_config = if !@cloud_monitoring.fluentd_conf_path.nil?
                            get_masked_conf_from_conf_file
                          elsif check_config_sending_usability
                            get_current_config_from_rpc
                          end

        if @cloud_monitoring.rate < 30
          log.warn "High frequency events ingestion is not supported. Set up 30s as ingestion interval"
          @cloud_monitoring[:rate] = 30
        end
        if setup_agent(@current_config)
          timer_execute(:in_calyptia_monitoring_send_metrics, @cloud_monitoring.rate, &method(:on_timer_send_metrics))
        else
          raise UpdateAgentError, "Setup agent is failed. Something went wrong"
        end
      end

      def create_agent(current_config)
        code, agent, machine_id = @api_requester.create_agent(current_config)
        if code.to_s.start_with?("2")
          @storage_agent.put(:agent, agent)
          @storage_agent.put(:machine_id, machine_id)
          return true
        else
          raise CreateAgentError, "Create agent is failed. Error: `#{agent["error"]}', code: #{code}"
        end
      end

      def setup_agent(current_config)
        if agent = @storage_agent.get(:agent)
          unless machine_id = @storage_agent.get(:machine_id)
            return create_agent(current_config)
          end
          code, body = @api_requester.update_agent(current_config, agent, machine_id)
          if code.to_s.start_with?("2")
            return true
          else
            log.warn "Updating agent is failed. Error: #{Yajl.load(body)["error"]}, Code: #{code}"
            return false
          end
        else
          create_agent(current_config)
        end
      end

      def check_config_sending_usability
        unless system_config.rpc_endpoint
          log.warn "This feature needs to enable RPC with `rpc_endpoint` on <system>."
          return false
        end

        res = retrieve_config_from_rpc
        if status = (res.code.to_i == 200)
          return status
        else
          log.warn "This feature needs to enable getDump RPC endpoint with `enable_get_dump` on <system>."
          return false
        end
      end

      def retrieve_config_from_rpc
        uri = URI.parse("http://#{system_config.rpc_endpoint}")
        res = Net::HTTP.start(uri.host, uri.port) {|http|
          http.get(RPC_CONFIG_DUMP_ENDPOINT)
        }
        res
      end

      def shutdown
        super
      end

      def append_pendings(buffer)
        @monitor.synchronize do
          if @pending.empty?
            @pending = [buffer]
          elsif @pending.size >= DEFAULT_PENDING_METRICS_SIZE
            drop_count = 1
            @pending = @pending.drop(drop_count)
            log.warn "pending buffer is full. Dropped the first element from the pending buffer"
            @pending.concat([buffer])
          else
            @pending.concat([buffer])
          end
        end
      end

      def add_metrics(buffer)
        return false unless agent = @storage_agent.get(:agent)

        begin
          code, response = if @pending.empty?
                             @api_requester.add_metrics(buffer, agent["token"], agent["id"])
                           else
                             @monitor.synchronize do
                               @pending = @pending.concat([buffer])
                               @api_requester.add_metrics(@pending.join, agent["token"], agent["id"])
                               @pending = []
                             end
                           end
          if response && response["error"]
            case code.to_i
            when *UNPROCESSABLE_HTTP_ERRORS
              log.warn "Sending metrics is failed and dropped metrics due to unprocessable on server. Error: `#{response["error"]}', Code: #{code}"
              return false
            end
            log.warn "Failed to send metrics. Error: `#{response["error"]}', Code: #{code}"
            append_pendings(buffer)
            return false
          end
        rescue => ex
          log.warn "Failed to send metrics: error = #{ex}, backtrace = #{ex.backtrace}"
          append_pendings(buffer)
          return false
        end
        return true
      end

      def on_timer_send_metrics
        opts = {with_config: false, with_retry: false}
        buffer = ""
        @monitor_agent.plugins_info_all(opts).each { |record|
          metrics = record["metrics"]
          metrics.each_pair do |k, v|
            buffer += v
          end
        }
        @monitor_agent_buffer.plugins_info_all(opts).each {|record|
          metrics = record["metrics"]
          metrics.each_pair do |k, v|
            buffer += v
          end
        }
        if buffer.empty?
          log.debug "No initialized metrics is found. Trying to send cmetrics on the next tick."
        else
          unless add_metrics(buffer)
            log.warn "Sending metrics is failed. Trying to send pending buffers in the next interval: #{@cloud_monitoring.rate}, next sending time: #{Time.now + @cloud_monitoring.rate}"
          end
        end
      end
    end
  end
end
