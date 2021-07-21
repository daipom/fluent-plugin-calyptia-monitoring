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

## Copyright

* Copyright(c) 2021- Hiroshi Hatake
* License
  * Apache License, Version 2.0
