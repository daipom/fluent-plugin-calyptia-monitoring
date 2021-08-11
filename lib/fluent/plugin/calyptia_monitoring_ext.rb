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
  class CalyptiaMonitoringExtInput < MonitorAgentInput
    CALYPTIA_PLUGIN_METRIC_INFO = {
      'emit_size' => ->(){
        throw(:skip) if @emit_size_metrics.get.nil?
        @emit_size_metrics.cmetrics.to_msgpack
      },
      'emit_records' => ->(){
        throw(:skip) if @emit_records_metrics.get.nil?
        @emit_records_metrics.cmetrics.to_msgpack
      },
      'retry_count' => ->(){
        throw(:skip) if @num_errors_metrics.get.nil?
        @num_errors_metrics.cmetrics.to_msgpack
      },
      'write_count' => ->(){
        throw(:skip) if @write_count_metrics.get.nil?
        @write_count_metrics.cmetrics.to_msgpack
      },
      'rollback_count' => ->(){
        throw(:skip) if @rollback_count_metrics.get.nil?
        @rollback_count_metrics.cmetrics.to_msgpack
      },
      'flush_time_count' => ->(){
        throw(:skip) if @flush_time_count_metrics.get.nil?
        @flush_time_count_metrics.cmetrics.to_msgpack
      },
      'slow_flush_count' => ->(){
        throw(:skip) if @slow_flush_count_metrics.get.nil?
        @slow_flush_count_metrics.cmetrics.to_msgpack
      },
    }

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
