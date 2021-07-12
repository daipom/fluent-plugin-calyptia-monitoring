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
require 'fluent/plugin/metrics'
require "fluent/plugin/input"
require_relative "calyptia_monitoring_ext"

module Fluent
  module Plugin
    class CalyptiaMonitoringInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("calyptia_monitoring", self)

      helpers :timer

      RPC_CONFIG_DUMP_ENDPOINT = "/api/config.getDump".freeze

      config_section :cloud_monitoring, multi: false do
        # desc 'The endpoint for Monitoring API HTTP request, e.g. http://example.com/api'
        # config_param :endpoint, :string
        # desc 'The API KEY for Monitoring API HTTP request
        # config_param :api_key, :string
        desc 'Emit monitoring values interval'
        config_param :rate, :time, default: 10
        desc 'Emit sending configuration interval'
        config_param :config_rate, :time, default: '1h'
      end
      desc 'The tag with which internal metrics are emitted.'
      config_param :tag, :string, default: nil

      def multi_workers_ready?
        true
      end

      def start
        super

        @use_cmetrics_msgpack_format = if system_config.metrics
                                         system_config.metrics[:@type] == "cmetrics"
                                       else
                                         false
                                       end
        @monitor_agent = Fluent::Plugin::CalyptiaMonitoringExtInput.new(@use_cmetrics_msgpack_format)
        timer_execute(:in_calyptia_monitoring_send_metrics, @cloud_monitoring.rate, &method(:on_timer_send_metrics))
        # Only works for worker 0.
        if check_config_sending_usability
          timer_execute(:in_calyptia_monitoring_send_config, @cloud_monitoring.config_rate, &method(:on_timer_send_config))
        end
      end

      def check_config_sending_usability
        return false unless fluentd_worker_id == 0
        unless system_config.rpc_endpoint
          log.warn "This feature needs to enable RPC with `rpc_endpoint` on <system>."
          return false
        end

        uri = URI.parse("http://#{system_config.rpc_endpoint}")
        res = Net::HTTP.start(uri.host, uri.port) {|http|
          http.get(RPC_CONFIG_DUMP_ENDPOINT)
        }
        if status = (res.code.to_i == 200)
          return status
        else
          log.warn "This feature needs to enable getDump RPC endpoint with `enable_get_dump` on <system>."
          return false
        end
      end

      def shutdown
        super
      end

      def on_timer_send_config
        if @tag
          log.debug "tag parameter is specified. Emit Fluentd configuration contents to '#{@tag}'"

          es = Fluent::MultiEventStream.new
          now = Fluent::EventTime.now

          uri = URI.parse("http://#{system_config.rpc_endpoint}")
          res = Net::HTTP.start(uri.host, uri.port) {|http|
            http.get(RPC_CONFIG_DUMP_ENDPOINT)
          }
          if res.code.to_i == 200
            conf = Yajl.load(res.body)["conf"]
            es.add(now, conf)
            router.emit_stream(@tag, es)
          end
        end
      end

      def on_timer_send_metrics
        if @tag
          log.debug "tag parameter is specified. Emit plugins info to '#{@tag}'"
          opts = {with_config: false, with_retry: false}
          es = Fluent::MultiEventStream.new
          now = Fluent::EventTime.now
          if @use_cmetrics_msgpack_format
            buffer = ""
            @monitor_agent.plugins_info_all(opts).each { |record|
              metrics = record["metrics"]
              metrics.each_pair do |k, v|
                buffer += v
              end
            }
            es.add(now, buffer)
          else
            metrics = {
              "metrics" => [],
            }
            @monitor_agent.plugins_info_all(opts).each { |metric|
              metrics["metrics"] << metric
            }
            es.add(now, metrics)
          end
          router.emit_stream(@tag, es)
        end
      end

      def collect_fluentd_info
        result = {}
        @monitor_agent.plugins_info_all.map { |plugin|
          id = plugin.delete('plugin_id')
          result[id] = plugin
        }
        result
      end

      def proxies
        ENV['HTTPS_PROXY'] || ENV['HTTP_PROXY'] || ENV['http_proxy'] || ENV['https_proxy']
      end

      def send_request(req, uri)
        res = nil
        begin
          if proxy = proxies
            proxy_uri = URI.parse(proxy)

            res = Net::HTTP.start(uri.host, uri.port,
                                  proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password,
                                  **http_opts(uri)) {|http| http.request(req) }
          else
            res = Net::HTTP.start(uri.host, uri.port, **http_opts(uri)) {|http| http.request(req) }
          end

        rescue => e # rescue all StandardErrors
          # server didn't respond
          log.warn "Net::HTTP.#{req.method.capitalize} raises exception: #{e.class}, '#{e.message}'"
        end
      end
    end
  end
end
