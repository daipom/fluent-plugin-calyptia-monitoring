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

      # desc 'The endpoint for Monitoring API HTTP request, e.g. http://example.com/api'
      # config_param :endpoint, :string
      desc 'Emit monitoring values interval'
      config_param :emit_interval, :time, default: 10
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
        timer_execute(:in_calyptia_monitoring, @emit_interval, &method(:on_timer))
      end

      def shutdown
        super
      end

      def on_timer
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
            @monitor_agent.plugins_info_all(opts).each { |record|
              es.add(now, record)
            }
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
