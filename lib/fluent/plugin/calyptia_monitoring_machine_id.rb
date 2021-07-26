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

require 'securerandom'

module Fluent::Plugin
  class CalyptiaMonitoringMachineId
    def initialize(worker_id, log)
      @worker_id = worker_id.to_i
      @log = log
    end

    def macos?
      RUBY_PLATFORM =~ /darwin/
    end

    def linux?
      RUBY_PLATFORM =~ /linux/
    end

    def windows?
      RUBY_PLATFORM =~ /mingw|mswin/
    end

    DBUS_MACHINE_ID_PATH = "/var/lib/dbus/machine-id".freeze
    ETC_MACHINE_ID_PATH = "/etc/machine-id".freeze

    def id
      if linux?
        linux_id
      elsif windows?
        windows_id
      elsif macos?
        macos_id
      end
    end

    private

    def macos_id
      require 'open3'
      o,_e, s = Open3.capture3 %q(ioreg -d2 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformUUID/{print $(NF-1)}')
      unless s.success?
        @log.info "MachineID is not retrived from ioreg. Using UUID instead."
        "#{SecureRandom.uuid}:#{@worker_id}"
      else
        # TODO: The prefix should be removed?
        "#{SecureRandom.hex(10)}_#{o.strip}:#{@worker_id}"
      end
    end

    def linux_id
      machine_id = ""
      begin
        machine_id = File.read(DBUS_MACHINE_ID_PATH).strip
      rescue Errno::NOENT
        machine_id = File.read(ETC_MACHINE_ID_PATH).strip rescue ""
      end
      if machine_id.empty?
        @log.info "MachineID is not retrived from #{DBUS_MACHINE_ID_PATH} or #{ETC_MACHINE_ID_PATH}. Using UUID instead."
        "#{SecureRandom.uuid}:#{@worker_id}"
      else
        # TODO: The prefix should be removed?
        "#{SecureRandom.hex(10)}_#{machine_id}:#{@worker_id}"
      end
    end

    def windows_id
      require 'win32/registry'

      machine_id = nil
      Win32::Registry::HKEY_LOCAL_MACHINE.open('SOFTWARE\\Microsoft\\Cryptography') do |key|
        machine_id = key.read("MachineGuid")[1] rescue ""
      end
      if machine_id.empty?
        @log.info "MachineID is not retrived from Registry. Using UUID instead."
        "#{SecureRandom.uuid}:#{@worker_id}"
      else
        # TODO: The prefix should be removed?
        "#{SecureRandom.hex(10)}_#{machine_id}:#{@worker_id}"
      end
    end
  end
end
