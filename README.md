# fluent-plugin-calyptia-monitoring

[Fluentd](https://fluentd.org/) input plugin to ingest metrics into Calyptia Cloud.

## Installation

### RubyGems

```
$ gem install fluent-plugin-calyptia-monitoring
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-calyptia-monitoring"
```

And then execute:

```
$ bundle
```

## Plugin helpers

* [timer](https://docs.fluentd.org/v/1.0/plugin-helper-overview/api-plugin-helper-timer)
* [storage](https://docs.fluentd.org/v/1.0/plugin-helper-overview/api-plugin-helper-storage)

* See also: [Input Plugin Overview](https://docs.fluentd.org/v/1.0/input#overview)

## Fluent::Plugin::CalyptiaMonitoringInput


### \<cloud_monitoring\> section (required) (single)

### Configuration

|parameter|type|description|default|
|---|---|---|---|
|endpoint|string (optional)|The endpoint for Monitoring API HTTP request, e.g. http://example.com/api|`TBD`|
|api_key|string (required)|The API KEY for Monitoring API HTTP request||
|rate|time (optional)|Emit monitoring values interval. (minimum interval is 30 seconds.)|`30`|
|pending_metrics_size|size (optional)|Setup pending metrics capacity size|`100`|

### Example

This plugin works well with [cmetrics Fluentd extension for metrics plugin](https://github.com/calyptia/fluent-plugin-metrics-cmetrics).

And enabling RPC and configDump endpoint is required if sending Fluentd configuration:

```aconf
<system>
# If users want to use multi workers feature which corresponds to logical number of CPUs, please comment out this line.
#  workers "#{require 'etc'; Etc.nprocessors}"
  enable_input_metrics true
  # This record size measuring settings might impact for performance.
  # Please be careful for high loaded environment to turn on.
  enable_size_metrics true
  <metrics>
    @type cmetrics
  </metrics>
  rpc_endpoint 127.0.0.1:24444
  enable_get_dump true
</system>
# And other configurations....

## Fill YOUR_API_KEY with your Calyptia API KEY
<source>
  @type calyptia_monitoring
  @id input_caplyptia_moniroting
  <cloud_monitoring>
    # endpoint http://development-environment-or-production.fqdn:5000
    api_key YOUR_API_KEY
    rate 30
    pending_metrics_size 100 # Specify capacity for pending metrics
  </cloud_monitoring>
  <storage>
    @type local
    path /path/to/agent/accessible/directories/agent_states
  </storage>
</source>
```

And also retrieving configuration from actual file is also supported:

```aconf
<system>
# If users want to use multi workers feature which corresponds to logical number of CPUs, please comment out this line.
#  workers "#{require 'etc'; Etc.nprocessors}"
  enable_input_metrics true
  # This record size measuring settings might impact for performance.
  # Please be careful for high loaded environment to turn on.
  enable_size_metrics true
  <metrics>
    @type cmetrics
  </metrics>
</system>
# And other configurations....

## Fill YOUR_API_KEY with your Calyptia API KEY
<source>
  @type calyptia_monitoring
  @id input_caplyptia_moniroting
  <cloud_monitoring>
    # endpoint http://development-environment-or-production.fqdn:5000
    api_key YOUR_API_KEY
    rate 30
    pending_metrics_size 100 # Specify capacity for pending metrics
    fluentd_conf_path /path/to/fluent.conf
  </cloud_monitoring>
  <storage>
    @type local
    path /path/to/agent/accessible/directories/agent_states
  </storage>
</source>
```

**Note:** We recommend to use RPC version due to some circumstances should differ between a loaded configuration and a saved Fluentd configuration.
This is because calling dumping config RPC feature can obtain from configuration contents which are loaded on memory. But retrieving configuration from the specified file is just read from the file contents and it cannot handle/retrieve loaded configurations on Fluentd.
When users just update their Fluentd configurations and forgot to restart/reload their Fluentd instances, loaded configurations differ from just edited ones.

## Calyptia Monitoring API config generator

Usage:

```
Usage: calyptia-config-generator api_key [options]

Generate Calyptia monitoring plugin config definitions

Arguments:
	api_key: Specify your API_KEY

Options:
        --endpoint URL               API Endpoint URL (default: nil, and if omitted, using default endpoint)
        --rpc-endpoint URL           Specify RPC Endpoint URL (default: 127.0.0.1:24444)
        --disable-input-metrics      Disable Input plugin metrics. Input metrics is enabled by default
        --enable-size-metrics        Enable event size metrics. Size metrics is disabled by default.
        --disable-get-dump           Disable RPC getDump procedure. getDump is enabled by default.
        --storage-agent-token-dir DIR
                                     Specify accesible storage token dir. (default: /path/to/accesible/dir)
        --fluentd-conf-path PATH     Specify fluentd configuration file path. (default: nil)
```

## Copyright

* Copyright(c) 2021- Calyptia Inc.
* Hiroshi Hatake <hatake@calyptia.com>
* License
  * Apache License, Version 2.0
