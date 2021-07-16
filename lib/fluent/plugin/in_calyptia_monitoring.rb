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
require 'time'
require 'fluent/version'
require 'fluent/plugin/metrics'
require "fluent/plugin/input"
require_relative "calyptia_monitoring_ext"
require_relative "calyptia_monitoring_calyptia_api_requester"

module Fluent
  module Plugin
    class CalyptiaMonitoringInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("calyptia_monitoring", self)

      helpers :timer, :storage

      RPC_CONFIG_DUMP_ENDPOINT = "/api/config.getDump".freeze
      DEFAULT_STORAGE_TYPE = 'local'

      config_section :cloud_monitoring, multi: false do
        desc 'The endpoint for Monitoring API HTTP request, e.g. http://example.com/api'
        config_param :endpoint, :string, default: "https://cloud-monitoring-api-dev.fluentbit.io"
        desc 'The API KEY for Monitoring API HTTP request'
        config_param :api_key, :string, secret: true
        desc 'Emit monitoring values interval'
        config_param :rate, :time, default: 10
      end

      def multi_workers_ready?
        true
      end

      def initialize
        super
        @agent_id = nil
        @current_config = nil
      end

      def configure(conf)
        super
        config = conf.elements.select{|e| e.name == 'storage' }.first
        @storage_agent = storage_create(usage: 'calyptia_monitoring_agent', conf: config, default_type: DEFAULT_STORAGE_TYPE)
      end

      def get_current_config_from_rpc
        uri = URI.parse("http://#{system_config.rpc_endpoint}")
        res = Net::HTTP.start(uri.host, uri.port) {|http|
          http.get(RPC_CONFIG_DUMP_ENDPOINT)
        }
        Yajl.load(res.body)["conf"]
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
        @api_requester = Fluent::Plugin::CalyptiaAPI::Requester.new(@cloud_monitoring.endpoint,
                                                                    @cloud_monitoring.api_key,
                                                                    log,
                                                                    fluentd_worker_id)
        if check_config_sending_usability
          @current_config = get_current_config_from_rpc
        end

        if setup_agent(@current_config)
          timer_execute(:in_calyptia_monitoring_send_metrics, @cloud_monitoring.rate, &method(:on_timer_send_metrics))
        end
      end

      def create_agent(current_config)
        code, agent, machine_id = @api_requester.create_agent(current_config)
        if agent["error"].nil?
          @storage_agent.put(:agent, agent)
          @storage_agent.put(:machine_id, machine_id)
          return true
        else
          raise RuntimeError, "Create agent is failed. Error: `#{agent["error"]}', code: #{code}"
        end
      end

      def setup_agent(current_config)
        if agent = @storage_agent.get(:agent)
          unless machine_id = @storage_agent.get(:machine_id)
            return create_agent(current_config)
          end
          @api_requester.update_agent(current_config, agent["id"], machine_id)
          return true
        else
          create_agent(current_config)
        end
      end

      def check_config_sending_usability
        unless system_config.rpc_endpoint
          log.warn "This feature needs to enable RPC with `rpc_endpoint` on <system>."
          return false
        end

        res = retrive_config_from_rpc
        if status = (res.code.to_i == 200)
          return status
        else
          log.warn "This feature needs to enable getDump RPC endpoint with `enable_get_dump` on <system>."
          return false
        end
      end

      def retrive_config_from_rpc
        uri = URI.parse("http://#{system_config.rpc_endpoint}")
        res = Net::HTTP.start(uri.host, uri.port) {|http|
          http.get(RPC_CONFIG_DUMP_ENDPOINT)
        }
        res
      end

      def shutdown
        super
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
        if agent = @storage_agent.get(:agent)
          code, response = @api_requester.add_metrics(buffer, agent["token"], agent["id"])
          unless response["error"].nil?
            log.warn "Sending metrics is failed. Error: `#{response["error"]}', Code: #{code}"
          end
        end
      end
    end
  end
end
