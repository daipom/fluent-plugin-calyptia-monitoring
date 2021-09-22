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

require 'fluent/plugin/in_monitor_agent'

module Fluent::Plugin
  class CalyptiaMonitoringInTailInput < MonitorAgentInput
    CALYPTIA_PLUGIN_METRIC_INFO = {
      'files_opened_total' => ->(){
        throw(:skip) unless instance_variable_defined?(:@metrics) && !@metrics.nil? && !@metrics.opened.get.nil?
        @metrics.opened.cmetrics.to_msgpack
      },
      'files_closed_total' => ->(){
        throw(:skip) unless instance_variable_defined?(:@metrics) && !@metrics.nil? && !@metrics.closed.get.nil?
        @metrics.closed.cmetrics.to_msgpack
      },
      'files_rotated_total' => ->(){
        throw(:skip) unless instance_variable_defined?(:@metrics) && !@metrics.nil? && !@metrics.rotated.get.nil?
        @metrics.rotated.cmetrics.to_msgpack
      },
    }

    def plugins_info_all(opts={})
      agent_info = all_plugins.select {|pe|
        pe.config['@type'] == "tail".freeze rescue nil
      }

      agent_info.map do |pe|
        get_monitor_info(pe, opts)
      end
    end

    def get_monitor_info(pe, opts = {})
      obj = {}

      obj['metrics'] = get_plugin_metric(pe)

      obj
    end

    def get_plugin_metric(pe)
      metrics = {}
      CALYPTIA_PLUGIN_METRIC_INFO.each_pair { |key, code|
        begin
          v = pe.instance_exec(&code)
          unless v.nil?
            metrics[key] = v
          end
        rescue
        end
      }

      metrics
    end
  end
end
