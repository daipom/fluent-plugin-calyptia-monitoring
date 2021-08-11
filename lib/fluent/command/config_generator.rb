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

require "erb"
require "optparse"
require "pathname"
require "fluent/plugin"
require "fluent/env"
require "fluent/engine"
require "fluent/system_config"
require "fluent/config/element"
require 'fluent/version'

class CalyptiaConfigGenerator
  def initialize(argv = ARGV)
    @argv = argv
    @api_key = nil
    @endpoint = nil
    @enable_input_metrics = true
    @enable_size_metrics = false
    @enable_get_dump = true
    @rpc_endpoint = "127.0.0.1:24444"
    @storage_agent_token_dir = default_storage_dir

    prepare_option_parser
  end

  def default_storage_dir
    if Fluent.windows?
      "C:/path/to/accesible/dir"
    else
      "/path/to/accesible/dir"
    end
  end

  def call
    parse_options!

    puts dump_configuration_for_calyptia
  end

  def dump_configuration_for_calyptia
    dumped = ""
    template = template_path("calyptia-conf.erb").read

    dumped <<
      if ERB.instance_method(:initialize).parameters.assoc(:key) # Ruby 2.6+
        ERB.new(template, trim_mode: "-")
      else
        ERB.new(template, nil, "-")
      end.result(binding)
    dumped
  end
  private

  def prepare_option_parser
    @parser = OptionParser.new
    @parser.version = Fluent::VERSION
    @parser.banner = <<BANNER
Usage: #{$0} api_key [options]

Output plugin config definitions

Arguments:
\tapi_key: Specify your API_KEY

Options:
BANNER
    @parser.on("--endpoint URL", "API Endpoint URL (default: nil, and if omitted, using default endpoint)") do |s|
      @endpoint = s
    end
    @parser.on("--rpc-endpoint URL", "Specify RPC Endpoint URL (default: 127.0.0.1:24444)") do |s|
      @rpc_endpoint = s
    end
    @parser.on("--disable-input-metrics", "Disable Input plugin metrics. Input metrics is enabled by default") do
      @enable_input_metrics = false
    end
    @parser.on("--enable-size-metrics", "Enable event size metrics. Size metrics is disabled by default.") do
      @enable_size_metrics = true
    end
    @parser.on("--disable-get-dump", "Disable RPC getDump procedure. getDump is enabled by default.") do
      @enable_get_dump = false
    end
    @parser.on("--storage-agent-token-dir DIR", "Specify accesible storage token dir. (default: #{default_storage_dir})") do |s|
      @storage_agent_token_dir = s
    end
  end

  def usage(message = nil)
    puts @parser.to_s
    puts
    puts "Error: #{message}" if message
    exit(false)
  end

  def parse_options!
    @parser.parse!(@argv)

    raise "Must specify api_key" unless @argv.size == 1

    @api_key, = @argv
    @options = {
      api_key: @api_key,
      endpoint: @endpoint,
      rpc_endpoint: @rpc_endpoint,
      input_metrics: @enable_input_metrics,
      size_metrics: @enable_size_metrics,
      enable_get_dump: @enable_get_dump,
      storage_agent_token_dir: @storage_agent_token_dir,
    }
  rescue => e
    usage(e)
  end

  def template_path(name)
    (Pathname(__dir__) + "../../../templates/#{name}").realpath
  end
end
