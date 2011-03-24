#!/usr/bin/env ruby

require 'network_base'
require 'graph_formats'
require 'set'
require 'sequel'

def import_files_into_db
end

def create_network
  net = Network.new
  
  Dir.glob("logs-utf8/*.txt") do |filename|
    project = File.basename(filename, '.txt')
    puts project
    
    authors = IO.readlines(filename).map { |x| x.split("\t")[1] }.uniq
    authors.each { |author| net.edge!(author, project) }
  end
  
  net.save2("nets/eclipse-commiter-project")
  
  return net
end

def convert_to_gml
  arc = read_pairs("nets/eclipse-commiter-project.arc")
  arc.to_gml.save_to_file("nets/eclipse-commiter-project.gml")
end

def transform_to_proj_proj
  net = Network.load2("nets/eclipse-commiter-project")
  net.to_undirected!
  
  p2p = Network.new
  
  projects = net.nodes.select { |x| x.eid.start_with? 'org.eclipse'  }
 
  p projects.map { |x| x.eid }
  exit 1

  projects.each do |project|
    puts project
    
    node = net.node?(project)
    others = node.neighbors.map { |x| x.neighbors }.flatten.uniq
    others = others.map(&:eid) - [node.eid]

    others.each { |e| p2p.edge!(project, e) }
    
  end
  
  #p2p.to_undirected!
  
  p2p.save2('eclipse-project-project')
  
  xxx = read_pairs('eclipse-project-project.arc')
  xxx.to_gml.save_to_file("nets/eclipse-project-project.gml")
  
  return p2p
end

class Commit
  attr_accessor :author, :project, :date

  def initialize(hash)
    author = hash[:author]
    project = hash[:project]
    date = hash[:date]
  end
end

# DSG dynamic graph file format, used by GraphStreamer
def create_dsg
  s = StringIO.new
  s << "DSG003\n\"Rodrigo\" 0 0\n"

  commits = []
  Dir.glob("logs-utf8/*.txt") do |filename|
    project = File.basename(filename, '.txt')
    puts project
    
    authors = IO.readlines(filename).map { |x| x.split("\t")[1] }.uniq
    authors.each { |author| net.edge!(author, project) }
  end

  return s.string
end

def transform_to_proj_proj2
  require 'rsruby'
  r = RSRuby.instance
  r.library 'igraph'

  g = r.read_graph('eclipse-commiter-project.arc', 'ncol')

  vertices = r.get_vertex_attribute(g, 'name')
  projects = vertices.select { |v| v.start_with?('org.eclipse') }
  p projects
  exit 1

  bip = r.bipartite_projection(g, projects)

  p blip
end

if __FILE__ == $0
  create_network
end
