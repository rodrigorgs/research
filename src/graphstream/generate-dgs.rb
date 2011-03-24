#!/usr/bin/env ruby

require 'git_logs/database'
require 'core/network_base'

class NetworkListener
  attr_accessor :file

  def initialize(file)
    self.file = file
  end

  def node_added(node)
    is_project = node.eid.start_with?("org.eclipse")
    klass = is_project ? "project" : "developer"
    label = is_project ? node.eid : ""
    s = %Q{an "#{node.eid}" ui.label="#{label}" ui.class="#{klass}"}
    file.puts s
  end

  def edge_added(edge)
    s = %Q{ae "#{edge.from.eid}-#{edge.to.eid}" "#{edge.from.eid}" "#{edge.to.eid}"}
    file.puts s
  end

  def cluster_added(cluster)
  end

  def network_added(net)
  end
end

if __FILE__ == $0
  GitLogDatabase.new

  min_time = Date.parse(DB[:commit].min(:time))
  max_time = Date.parse(DB[:commit].max(:time))

  total_interval = max_time - min_time
  interval = 7 # days
  num_steps = (total_interval / interval).to_i + 1

  f = File.open("/tmp/bli.dgs", "w")
  f.puts "DGS003"
  f.puts '"Rodrigo" 0 0'

  net = Network.new
  listener = NetworkListener.new(f)
  net.change_listener = listener

  num_steps.times do |frame|
    STDERR.puts "#{frame} / #{num_steps}"
    f.puts "st #{frame}"

    date1 = min_time + (frame * interval)
    date2 = date1 + interval

    ds = Commit.filter{time >= date1}.and{time < date2}
    ds.each do |commit|
      author = commit.author.name
      project = commit.project.name
      net.edge!(author, project)
    end
  end

  f.close
end
