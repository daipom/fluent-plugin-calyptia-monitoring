require 'helper'
require 'tmpdir'
require 'fluent/command/config_generator'

class TestCalyptiaConfigGenerator < Test::Unit::TestCase
  def stringio_stdout
    out = StringIO.new
    $stdout = out
    yield
    out.string.force_encoding('utf-8')
  ensure
    $stdout = STDOUT
  end

  def default_storage_dir
    if Fluent.windows?
      "C:/path/to/accesible/dir"
    else
      "/path/to/accesible/dir"
    end
  end

  sub_test_case "generate configuration" do
    test "with only api_key" do
      dumped_config = capture_stdout do
        CalyptiaConfigGenerator.new(["YOUR_API_KEY"]).call
      end
      expected =<<TEXT
<system>
  <metrics>
    @type cmetrics
  </metrics>
  enable_input_metrics true
  enable_size_metrics false
  rpc_endpoint 127.0.0.1:24444
  enable_get_dump true
<system>
<source>
  @type calyptia_monitoring
  @id input_caplyptia_monitoring
  <cloud_monitoring>
    api_key YOUR_API_KEY
  </cloud_monitoring>
  <storage>
    @type local
    path #{default_storage_dir}/agent_state
  </storage>
</source>
TEXT
      assert_equal(expected, dumped_config)
    end

    test "with api_key and enable_input_metrics" do
      dumped_config = capture_stdout do
        CalyptiaConfigGenerator.new(["YOUR_API_KEY", "--disable-input-metrics"]).call
      end
      expected =<<TEXT
<system>
  <metrics>
    @type cmetrics
  </metrics>
  enable_input_metrics false
  enable_size_metrics false
  rpc_endpoint 127.0.0.1:24444
  enable_get_dump true
<system>
<source>
  @type calyptia_monitoring
  @id input_caplyptia_monitoring
  <cloud_monitoring>
    api_key YOUR_API_KEY
  </cloud_monitoring>
  <storage>
    @type local
    path #{default_storage_dir}/agent_state
  </storage>
</source>
TEXT
      assert_equal(expected, dumped_config)
    end

    test "with api_key and rpc-endpoint" do
      dumped_config = capture_stdout do
        CalyptiaConfigGenerator.new(["YOUR_API_KEY", "--rpc-endpoint", "localhost:24445"]).call
      end
      expected =<<TEXT
<system>
  <metrics>
    @type cmetrics
  </metrics>
  enable_input_metrics true
  enable_size_metrics false
  rpc_endpoint localhost:24445
  enable_get_dump true
<system>
<source>
  @type calyptia_monitoring
  @id input_caplyptia_monitoring
  <cloud_monitoring>
    api_key YOUR_API_KEY
  </cloud_monitoring>
  <storage>
    @type local
    path #{default_storage_dir}/agent_state
  </storage>
</source>
TEXT
      assert_equal(expected, dumped_config)
    end

    test "with api_key and enable_size_metrics" do
      dumped_config = capture_stdout do
        CalyptiaConfigGenerator.new(["YOUR_API_KEY", "--enable-size-metrics"]).call
      end
      expected =<<TEXT
<system>
  <metrics>
    @type cmetrics
  </metrics>
  enable_input_metrics true
  enable_size_metrics true
  rpc_endpoint 127.0.0.1:24444
  enable_get_dump true
<system>
<source>
  @type calyptia_monitoring
  @id input_caplyptia_monitoring
  <cloud_monitoring>
    api_key YOUR_API_KEY
  </cloud_monitoring>
  <storage>
    @type local
    path #{default_storage_dir}/agent_state
  </storage>
</source>
TEXT
      assert_equal(expected, dumped_config)
    end

    test "with api_key and disable_get_dump" do
      dumped_config = capture_stdout do
        CalyptiaConfigGenerator.new(["YOUR_API_KEY", "--disable-get-dump"]).call
      end
      expected =<<TEXT
<system>
  <metrics>
    @type cmetrics
  </metrics>
  enable_input_metrics true
  enable_size_metrics false
  rpc_endpoint 127.0.0.1:24444
  enable_get_dump false
<system>
<source>
  @type calyptia_monitoring
  @id input_caplyptia_monitoring
  <cloud_monitoring>
    api_key YOUR_API_KEY
  </cloud_monitoring>
  <storage>
    @type local
    path #{default_storage_dir}/agent_state
  </storage>
</source>
TEXT
      assert_equal(expected, dumped_config)
    end

    test "with api_key and storage_agent_token_dir" do
      storage_dir = Dir.tmpdir
      dumped_config = capture_stdout do
        CalyptiaConfigGenerator.new(["YOUR_API_KEY", "--storage_agent_token_dir", storage_dir]).call
      end
      expected =<<TEXT
<system>
  <metrics>
    @type cmetrics
  </metrics>
  enable_input_metrics true
  enable_size_metrics false
  rpc_endpoint 127.0.0.1:24444
  enable_get_dump true
<system>
<source>
  @type calyptia_monitoring
  @id input_caplyptia_monitoring
  <cloud_monitoring>
    api_key YOUR_API_KEY
  </cloud_monitoring>
  <storage>
    @type local
    path #{storage_dir}/agent_state
  </storage>
</source>
TEXT
      assert_equal(expected, dumped_config)
    end
  end
end
