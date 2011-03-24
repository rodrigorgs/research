#!/usr/bin/env ruby

=begin

Parameters:
1. Path of a local git repository containing source code
2. Path of the database where the result is to be created

=end

require 'core/doxyparse'
require 'core/scm'
require 'git/database'


