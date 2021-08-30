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
  class CalyptiaMonitoringBufferExtInput < MonitorAgentInput
    CALYPTIA_PLUGIN_BUFFER_METRIC_INFO = {
      'buffer_total_queued_size' => ->() {
        throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
        @buffer.total_queued_size_metrics.cmetrics.to_msgpack
      },
      'buffer_stage_length' => ->() {
        throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
        @buffer.stage_length_metrics.cmetrics.to_msgpack
      },
      'buffer_stage_byte_size' => ->() {
        throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
        @buffer.stage_size_metrics.cmetrics.to_msgpack
      },
      'buffer_queue_length' => ->() {
        throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
        @buffer.queue_length_metrics.cmetrics.to_msgpack
      },
      'buffer_queue_byte_size' => ->() {
        throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
        @buffer.queue_size_metrics.cmetrics.to_msgpack
      },
      'available_buffer_space_ratios' => ->() {
        throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
        @buffer.available_buffer_space_ratios_metrics.cmetrics.to_msgpack
      },
      'newest_timekey' => ->() {
        throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
        @buffer.newest_timekey_metrics.cmetrics.to_msgpack
      },
      'oldest_timekey' => ->() {
        throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
        @buffer.oldest_timekey_metrics.cmetrics.to_msgpack
      },
    }

    def get_monitor_info(pe, opts = {})
      obj = {}

      obj['metrics'] = get_plugin_metric(pe)

      obj
    end

    def get_plugin_metric(pe)
      # Nop for non output plugin
      return {} if plugin_category(pe) != "output"

      metrics = {}

      if pe.respond_to?(:statistics)
        # Force to update buffers' metrics values
        pe.statistics
      end

      CALYPTIA_PLUGIN_BUFFER_METRIC_INFO.each_pair { |key, code|
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
