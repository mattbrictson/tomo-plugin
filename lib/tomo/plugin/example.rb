require "tomo"
require_relative "example/helpers"
require_relative "example/tasks"
require_relative "example/version"

module Tomo::Plugin::Example
  extend Tomo::PluginDSL

  # TODO: initialize this plugin's settings with default values
  # defaults plugin_name_setting: "foo",
  #          plugin_name_another_setting: "bar"

  tasks Tomo::Plugin::Example::Tasks
  helpers Tomo::Plugin::Example::Helpers
end
