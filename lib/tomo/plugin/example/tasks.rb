# frozen_string_literal: true

module Tomo::Plugin::Example
  class Tasks < Tomo::TaskLibrary
    # Defines a example:hello task
    def hello
      remote.run "echo", "hello, world"
    end
  end
end
