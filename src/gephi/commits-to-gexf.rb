#!/usr/bin/env ruby
# Reads commits from a SQL database (see git_logs/database.rb) and outputs
# a dynamic GEXF (graph file format) to be open in Gephi.
# See: http://wiki.gephi.org/index.php/Import_Dynamic_Data
# See also: http://gexf.net/1.1draft/gexf-11draft-primer.pdf

# TODO: use primary key as gephi's node/edge id.

require 'git_logs/database'

CLUSTER_PROJECTS = true

def read_data
  database = GitLogDatabase.new

  #developers = Author.all
  #projects = Project.all
  
  min_date = DB["SELECT MIN(time) AS min FROM 'commit'"].first[:min]
  max_date = DB["SELECT MAX(time) AS max FROM 'commit'"].first[:max]

  ds = DB["
  SELECT developer.name,
    MIN('commit'.time) AS min, 
    MAX('commit'.time) AS max
  FROM 'commit'
  INNER JOIN 'developer' ON 'commit'.developer_id = developer.id
  GROUP BY 1
  "]
 
  developer_data = ds.all

  ds = DB["
  SELECT project.name,
    MIN('commit'.time) AS min, 
    MAX('commit'.time) AS max
  FROM 'commit'
  INNER JOIN 'project' ON 'commit'.project_id = project.id
  GROUP BY 1
  "]

  project_data = ds.all

  if CLUSTER_PROJECTS
    groups = project_data.group_by do |hash| 
      if hash[:name] =~ /^org\.eclipse\.([^\.]*)/
        $1
      else
        hash[:name]
      end
    end

    project_data = []
    groups.each do |project, hashes|
      min = hashes.map { |h| h[:min] }.min
      max = hashes.map { |h| h[:max] }.max
      project_data << {:name => project, :min => min, :max => max}
    end
  end

  #project_data.each { |x| p x }

  ds = DB["
  SELECT developer.name AS developer, 
    project.name AS project,
    MIN('commit'.time) AS min, 
    MAX('commit'.time) AS max
  FROM 'commit'
  INNER JOIN 'developer' ON 'commit'.developer_id = developer.id
  INNER JOIN 'project' ON 'commit'.project_id = project.id
  GROUP BY 1, 2
  "]

  edge_data = ds.all

  if CLUSTER_PROJECTS
    groups = edge_data.group_by do |hash| 
      if hash[:project] =~ /^org\.eclipse\.([^\.]*)/
        [$1, hash[:developer]]
      else
        [hash[:project], hash[:developer]]
      end
    end

    edge_data = []
    groups.each do |array, hashes|
      project, developer = array
      min = hashes.map { |h| h[:min] }.min
      max = hashes.map { |h| h[:max] }.max
      edge_data << {:developer => developer, :project => project, :min => min, :max => max}
    end
  end

  return min_date, max_date, developer_data, project_data, edge_data
end

def to_isodate(s)
  return Date.parse(s).iso8601
end

def insert_nodes(list, file, color=[0,0,0])
  # TODO: receive a hash -- ex.: :color => red -- and output hash keys as xml attributes
  list.each do |elem|
    start = to_isodate(elem[:min])
    finish = to_isodate(elem[:max])
    name = elem[:name]
    file.puts %Q{<node id="#{name}" label="#{name}" start="#{start}" end="#{finish}">}
    file.puts %Q{  <viz:color r="#{color[0]}" g="#{color[1]}" b="#{color[2]}" />}
    file.puts %Q{</node>}
  end
end

if __FILE__ == $0
  ##############################################

  min_date, max_date, developer_data, project_data, edge_data = read_data

  ##############################################
  
  file = File.open("/tmp/bli.gexf", "w")

  min_date
  file.puts %Q{<gexf xmlns="http://www.gexf.net/1.1draft"
     xmlns:viz="http://www.gexf.net/1.1draft/viz"
     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
     xsi:schemaLocation="http://www.gexf.net/1.1draft
                         http://www.gexf.net/1.1draft/gexf.xsd"
    version="1.1">
<graph mode="dynamic" defaultedgetype="undirected" 
  start="#{to_isodate(min_date)}" end="#{to_isodate(max_date)}"
  timetype="date">}

  file.puts '<nodes>'
  insert_nodes(developer_data, file, [255, 0, 0])
  insert_nodes(project_data, file, [0, 0, 0])
  file.puts '</nodes>'

  file.puts '<edges>'
  edge_data.each do |elem|
    start = to_isodate(elem[:min])
    finish = to_isodate(elem[:max])
    file.puts %Q{<edge source="#{elem[:developer]}" target="#{elem[:project]}" start="#{start}" end="#{finish}" />}
  end
  file.puts '</edges>'

  file.puts '  </graph>
</gexf>'

  file.close
end
