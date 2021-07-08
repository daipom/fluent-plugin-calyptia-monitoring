require 'fluent/plugin/in_monitor_agent'

module Fluent::Plugin
  class CalyptiaMonitoringExtInput < MonitorAgentInput

    def initialize(use_cmetrics_msgpack_format)
      @use_cmetrics_msgpack_format = use_cmetrics_msgpack_format
    end

    CALYPTIA_PLUGIN_METRIC_INFO = {
      'emit_size' => ->(){
        if !@emit_size_metrics.nil?
          if @emit_size_metrics.respond_to?(:cmetrics)
            @emit_size_metrics.cmetrics.to_msgpack
          else
            emit_size
          end
        else
          @emit_size
        end
      },
      'emit_records' => ->(){
        if !@emit_records_metrics.nil?
          if @emit_records_metrics.respond_to?(:cmetrics)
            @emit_records_metrics.cmetrics.to_msgpack
          else
            emit_records
          end
        else
          @emit_records
        end
      },
      'retry_count' => ->(){
        throw(:skip) unless instance_variable_defined?(:@buffer) && !@buffer.nil? && @buffer.is_a?(::Fluent::Plugin::Buffer)
        begin
          if !@num_errors_metrics.nil?
            if @num_errors_metrics.respond_to?(:cmetrics)
              @num_errors_metrics.cmetrics.to_msgpack
            else
              num_errors
            end
          end
        rescue
          0
        end
      },
    }

    def get_monitor_info(pe, opts = {})
      obj = {
        'plugin_id'.freeze => pe.plugin_id,
        'type'.freeze => pe.config['@type'.freeze] || pe.config['type'.freeze],
        'plugin_category'.freeze => plugin_category(pe),
        'worker_id'.freeze => pe.fluentd_worker_id,
      }

      if @use_cmetrics_msgpack_format
        obj['metrics'] = get_plugin_metric(pe)
      else
        obj.merge!(get_plugin_metric(pe))
      end

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
