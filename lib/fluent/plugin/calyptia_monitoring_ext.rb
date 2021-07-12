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

    def metric_template(pe, key, value)
      name = if pe.plugin_id_configured?
               "#{pe.plugin_id}"
             else
               "#{pe.config['@type'.freeze] || pe.config['type'.freeze]}_#{self.plugin_id}"
             end
      type = pe.config['@type'.freeze] || pe.config['type'.freeze]
      return {
        "type" => 0,
        "opts" => {
          "namespace" => plugin_category(pe),
          "subsystem" => type,
          "name" => key,
          "fqname" => "#{plugin_category(pe)}.#{name}.#{key}",
        },
        "labels" => [],
        "values" => [
          "ts" => (Time.now.to_f * 10**9).to_i,
          "value" => value,
          "labels" => []
        ]
      }
    end

    def get_monitor_info(pe, opts = {})
      obj = {}

      if @use_cmetrics_msgpack_format
        obj['metrics'] = get_plugin_metric(pe)
      else
        get_plugin_metric(pe).each do |k, v|
          obj.merge!(metric_template(pe, k, v))
        end
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
