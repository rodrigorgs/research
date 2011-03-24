#!/usr/bin/env ruby
require 'net/http'

# Reads a DSG and streams it over HTTP, step by step, to a Gephi Streaming 
# client.

if __FILE__ == $0
  filename = "/tmp/bli.dgs"
  file = File.open(filename, "r")

  # TODO: accumulate lines and stop when find a "st" (step) instruction,
  # then send the lines after a time interval or after user keypress.
  # TODO: to be Gephi compatible, replace ui.label by Label

  File.each do |line|
  end

  file.close
end
