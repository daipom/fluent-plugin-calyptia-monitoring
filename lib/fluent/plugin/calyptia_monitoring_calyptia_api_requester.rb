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
require 'securerandom'
require 'socket'
require 'yajl'
require 'fluent/system_config'
require_relative 'calyptia_monitoring_machine_id'

module Fluent::Plugin
  class CalyptiaAPI
    class Requester
      include Fluent::SystemConfig::Mixin

      def initialize(endpoint, api_key, log, worker_id)
        @endpoint = endpoint
        @api_key = api_key
        @log = log
        @worker_id = worker_id
        @machine_id = Fluent::Plugin::CalyptiaMonitoringMachineId.new(worker_id, log)
      end

      def proxies
        ENV['HTTPS_PROXY'] || ENV['HTTP_PROXY'] || ENV['http_proxy'] || ENV['https_proxy']
      end

      def create_go_semver(version)
        version.gsub(/.(?<prever>(rc|alpha|beta|pre))/,
                     '-\k<prever>')
      end

      def agent_metadata(current_config)
        metadata = {
          "name" => Socket.gethostname,
          "type" => "fluentd",
          "rawConfig" => current_config,
          "version" => create_go_semver(Fluent::VERSION),
          "edition" => "community".freeze,
        }
        if system_config.workers.to_i > 1
          metadata["flags"] = ["number_of_workers=#{system_config.workers}", "worker_id=#{@worker_id}"]
        end
        metadata
      end

      # POST /v1/agents
      # Authorization: X-Project-Token
      def create_agent(current_config)
        url = URI("#{@endpoint}/v1/agents")

        https = if proxy = proxies
                  proxy_uri = URI.parse(proxy)
                  Net::NTTP.new(uri.host, uri.port,
                                proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
                else
                  Net::HTTP.new(url.host, url.port)
                end
        https.use_ssl = (url.scheme == "https")
        machine_id = @machine_id.id
        @log.debug "send creating agent request"
        request = Net::HTTP::Post.new(url)
        request["X-Project-Token"] = @api_key
        request["Content-Type"] = "application/json"
        request.body = Yajl.dump(agent_metadata(current_config).merge("machineID" => machine_id))
        response = https.request(request)
        agent = Yajl.load(response.read_body)
        return [response.code, agent, machine_id]
      end

      # PATCH /v1/agents/:agent_id
      # Authorization: X-Agent-Token
      def update_agent(current_config, agent, machine_id)
        url = URI("#{@endpoint}/v1/agents/#{agent['id']}")

        https = if proxy = proxies
                  proxy_uri = URI.parse(proxy)
                  Net::NTTP.new(uri.host, uri.port,
                                proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
                else
                  Net::HTTP.new(url.host, url.port)
                end
        https.use_ssl = (url.scheme == "https")

        @log.debug "send updating agent request"
        request = Net::HTTP::Patch.new(url)
        request["X-Agent-Token"] = agent['token']
        request["Content-Type"] = "application/json"

        request.body = Yajl.dump(agent_metadata(current_config).merge("machineID" => machine_id))
        response = https.request(request)
        body = response.read_body
        return [response.code, body]
      end

      # POST /v1/agents/:agent_id/metrics
      # Authorization: X-Agent-Token
      def add_metrics(metrics, agent_token, agent_id)
        url = URI("#{@endpoint}/v1/agent_metrics")

        https = if proxy = proxies
                  proxy_uri = URI.parse(proxy)
                  Net::NTTP.new(uri.host, uri.port,
                                proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
                else
                  Net::HTTP.new(url.host, url.port)
                end
        https.use_ssl = (url.scheme == "https")

        @log.debug "send adding agent metrics request"
        request = Net::HTTP::Post.new(url)
        request["X-Agent-Token"] = agent_token
        request["Content-Type"] = "application/x-msgpack"

        request.body = metrics

        response = https.request(request)
        return [response.code, Yajl.load(response.read_body)]
      end
    end
  end
end
