require "helper"
require "logger"
require "fluent/plugin/calyptia_monitoring_calyptia_api_requester"

class CalyptiaMonitoringMachineIdTest < Test::Unit::TestCase
  API_KEY = 'YOUR_API_KEY'.freeze
  API_ENDPOINT = "https://cloud-api.calyptia.com".freeze

  setup do
    @log = Logger.new($stdout)
    worker_id = [1,2,3,4,5,6,7,8,9,10,11].sample
    @api_requester = Fluent::Plugin::CalyptiaAPI::Requester.new(API_ENDPOINT,
                                                                API_KEY,
                                                                @log,
                                                                worker_id)
  end

  data("rc" => ["1.14.0.rc", "1.14.0-rc"],
       "rc2" => ["1.14.0.rc2", "1.14.0-rc2"],
       "alpha" => ["1.14.0.alpha", "1.14.0-alpha"],
       "beta" => ["1.14.0.beta", "1.14.0-beta"],
       "pre" => ["1.14.0.pre", "1.14.0-pre"],
      )
  def test_create_go_semver(data)
    version, expected = data
    actual = @api_requester.create_go_semver(version)
    assert_equal expected, actual
  end
end
