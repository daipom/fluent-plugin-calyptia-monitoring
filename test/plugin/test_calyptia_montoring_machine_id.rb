require "helper"
require "logger"
require "fluent/plugin/in_calyptia_monitoring.rb"

class CalyptiaMonitoringMachineIdTest < Test::Unit::TestCase
  setup do
    @log = Logger.new($stdout)
    worker_id = [1,2,3,4,5,6,7,8,9,10,11].sample
    @machine_id = @machine_id = Fluent::Plugin::CalyptiaMonitoringMachineId.new(worker_id, @log)
  end

  test "Retrive machineID" do
    machine_id = @machine_id.id
    assert_not_nil machine_id
  end
end
