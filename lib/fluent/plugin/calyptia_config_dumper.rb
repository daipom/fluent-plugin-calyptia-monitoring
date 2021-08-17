#!/usr/bin/env ruby

require 'fluent/env'
require 'fluent/engine'
require 'fluent/log'
require 'fluent/config'
require 'fluent/configurable'
require 'fluent/system_config'
require 'fluent/config/element'
require 'serverengine'
require 'stringio'

include Fluent::Configurable

def init_log
  dl_opts = {}
  dl_opts[:log_level] = ServerEngine::DaemonLogger::WARN
  @sio = StringIO.new('', 'r+')
  logger = ServerEngine::DaemonLogger.new(@sio, dl_opts)
  $log = Fluent::Log.new(logger)
end

init_log

File.open(ENV["FLUENT_CONFIG_PATH"], "r") do |f|
  config = Fluent::Config.parse(f.read, '(supervisor)', '(readFromFile)', true)
  system_config = Fluent::SystemConfig.create(config)
  Fluent::Engine.init(system_config, supervisor_mode: true)
  Fluent::Engine.run_configure(config, dry_run: true)
  confs = []
  masked_element = config.to_masked_element
  masked_element.elements.each{|e|
    confs << e.to_s
  }
  puts confs.join
end
