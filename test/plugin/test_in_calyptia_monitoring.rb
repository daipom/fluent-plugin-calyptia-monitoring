require "helper"
require "fluent/plugin/in_calyptia_monitoring.rb"

class CalyptiaMonitoringInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  test "failure" do
    flunk
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::CalyptiaMonitoringInput).configure(conf)
  end
end
