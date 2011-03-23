#!/usr/bin/env ruby
#
# Model of a directed network with one-level communities/modules/clusters
#

require 'set'
require 'stringio'

class Network
  attr_reader :edges, :data
  attr_accessor :change_listener

  def _init
    @nodes    = {}
    @clusters = {}
    @edges    = []
    @default_cluster = Cluster.new('DEFAULT')
    @data = LazyHash2.new
  end

  def external_edges
    edges.select { |e| e.from.cluster != e.to.cluster }
  end


  def save(edges_file, modules_file, attr=nil)
    File.open(edges_file, "w") do |f|
      if attr.nil?
        edges.each { |e| f.puts "#{e.from.eid} #{e.to.eid}" }
      else
        edges.each { |e| f.puts "#{e.from.data.send(attr)} #{e.to.data.send(attr)}" }
      end
    end
    File.open(modules_file, "w") do |f|
      if attr.nil?
        nodes.each { |n| f.puts "#{n.eid} #{n.cluster.eid}" }
      else
        nodes.each { |n| f.puts "#{n.data.send(attr)} #{n.cluster.data.send(attr)}" }
      end
    end
    true
  end

  def save2(basename, attributed=:eid)
    save(basename + '.arc', basename + '.mod')
    true
  end

  def Network.load(*args)
    n = Network.new
    n.load(*args)
    return n
  end
  
  def Network.load2(*args)
    n = Network.new
    n.load2(*args)
    return n
  end


  def load_from_string(arc, mod)
    arc = arc.strip.split("\n").map { |x| x.split(' ') }
    mod = mod.strip.split("\n").map { |x| x.split(' ') }
    check_no_overlapping_modules_pairs(mod)
    set_clusters(mod)
    add_edges(arc)
    return self
  end

  def arc_string
    s = StringIO.new
    edges.each { |e| s << "#{e.from.eid} #{e.to.eid}\n" }
    return s.string.chomp
  end

  def mod_string
    s = StringIO.new
    nodes.each { |n| s << "#{n.eid} #{n.cluster.eid}\n" }
    return s.string.chomp
  end

  # using PAIRS format
  def load(edges_file, modules_file)
    edges_file = read_pairs(edges_file) if edges_file.kind_of?(String)
    modules_file = read_pairs(modules_file) if modules_file.kind_of?(String)

    check_no_overlapping_modules_pairs(modules_file)

    set_clusters(modules_file) unless modules_file.nil?
    add_edges(edges_file) unless edges_file.nil?
  end

  def check_no_overlapping_modules_pairs(modules_pairs)
    return if modules_pairs.nil?
    node_labels = modules_pairs.map { |a, b| a }
    if node_labels.uniq.size != node_labels.size
      raise 'There are nodes in more than one module' 
    end
  end

  def load2(basename)
    basename = basename[0..-2] if basename[-1..-1] == '.'
    load(basename + '.arc', basename + '.mod')
  end

  # Factory methods

  def new_node(eid)
    x = Node.new(eid)
    change_listener.node_added(x) if change_listener
    return x
  end

  def new_edge(n1, n2)
    x = Edge.new(n1, n2)
    change_listener.edge_added(x) if change_listener
    return x
  end

  def new_cluster(eid)
    x = Cluster.new(eid)
    change_listener.cluster_added(x) if change_listener
    return x
  end

  def new_network
    x = Network.new
    change_listener.network_added(x) if change_listener
    return x
  end

  # ------ end Factory methods
  def edges_undirected
    edges.map { |e| [e.from, e.to].sort_by { |x| x.eid} }.uniq.map { |a, b| new_edge(a, b) }
  end

  # using PAIRS format
  def initialize(_edges=nil, _modules=nil)
    _init
    load(_edges, _modules)
  end

  def node!(eid, cluster=nil)
    return eid if eid.kind_of?(Node)
    node = @nodes[eid]
    if node.nil?
      node = new_node(eid)
      set_cluster(node, cluster!(cluster))
      @nodes[eid] = node
    end
    return node
  end
 
  def node?(eid)
    return eid if eid.kind_of?(Node)
    return @nodes[eid]
  end

  def edge!(n1, n2, cluster1=nil, cluster2=nil)
    n1 = node!(n1, cluster!(cluster1))
    n2 = node!(n2, cluster!(cluster2))
    edge = if (n1.out_edges_map.size > n2.in_edges_map.size)
      n1.out_edges_map[n2]
    else
      n2.in_edges_map[n1]
    end
    if edge.nil?
      edge = new_edge(n1, n2)
      @edges << edge
      n1.out_edges_map[n2] = edge
      n2.in_edges_map[n1] = edge
    end
    return edge
  end

  def edge?(n1, n2)
    n1 = node?(n1)
    n2 = node?(n2)
    return nil if n1.nil? || n2.nil?
    return n1.out_edges_map[n2]
  end

  def cluster!(eid)
    return eid if eid.kind_of?(Cluster)
    return @default_cluster if eid.nil?
    cluster = @clusters[eid]
    if cluster.nil?
      cluster = new_cluster(eid)
      @clusters[eid] = cluster
    end
    return cluster
  end

  def cluster?(eid)
    return eid if eid.kind_of?(Cluster)
    return @default_cluster if eid.nil?
    return @clusters[eid]
  end

  def nodes
    @nodes.values
  end

  def clusters
    @clusters.values
  end

  def set_cluster(node, cluster)
    node = node!(node)
    cluster = cluster.nil? ? @default_cluster : cluster!(cluster)

    if cluster != node.cluster
      node.cluster._remove(node) if !node.cluster.nil? 
      cluster._add(node)
      node._cluster= cluster
    end
  end

  def add_edges(pairs)
    pairs.each { |n1, n2| edge!(n1, n2) }
    self
  end

  def set_clusters(pairs)
    pairs.each { |node, cluster| set_cluster(node, cluster) }
  end

  def size
    @nodes.size
  end

  def lift
    links = self.edges.map { |e| [e.from.cluster.eid, e.to.cluster.eid] }.uniq
    g = new_network
    self.clusters.each { |c| g.node!(c.eid, 0) }
    g.add_edges(links.select { |l| l[0] != l[1] } )
    return g
  end

  # TODO: move to node
  def clustering_coefficient(node)
    node = node?(node)
    return 0 if node.nil?

    neighbors = node.neighbors
    return 0.0 if (neighbors.size < 2)
    nlinks = 0
    neighbors.each do |a|
      neighbors.each do |b|
        nlinks += 1 if a != b && edge?(a, b)
      end
    end

    return nlinks.to_f / (neighbors.size * (neighbors.size - 1))
  end

  def to_undirected!
    current_edges = edges.dup
    current_edges.each { |e| edge!(e.to, e.from) }
  end

  def remove_edge(e)
    return if e.nil?
    e.from.out_edges_map.delete(e.to)
    e.to.in_edges_map.delete(e.from)
    @edges.delete(e) 
  end

  def remove_node(n)
    n = node?(n)
    return if n.nil?
    n.edges.each { |e| remove_edge(e) }
    @nodes.delete(n.eid)
  end

  def remove_cluster(c)
    c = cluster?(c)
    c.nodes.each { |n| remove_node(n) }
    @clusters.delete(c.eid)
  end

  def dyad_census
    edges.each { |e| e.data.visited = false }
    census = { 
      :external_asym => 0,
      :external_mutual => 0,
      :internal_asym => 0,
      :internal_mutual => 0,
      }
    type = nil

    edges.each do |e|
      next if e.data.visited
      e.data.visited = true
      if e.to.connects_to(e.from) # mutual
        edge?(e.to, e.from).data.visited = true
        type = (e.from.cluster == e.to.cluster) ? :internal_mutual : :external_mutual
      else
        type = (e.from.cluster == e.to.cluster) ? :internal_asym : :external_asym
      end
      census[type] += 1
    end

    sum = census.values.inject(0) { |acc, x| acc + x }.to_f
    census.keys.each { |k| census[k] /= sum }
    return census
  end

  ###############################################

  def inspect
    ""
  end

  def dot_id(id)
    id.gsub(/[^A-Za-z0-9]/, "_")
  end

  def to_dot
    s = "digraph G {\n"
    nodes.each { |n| s += "#{dot_id(n.eid)}[shape=box];\n" }
    edges.each { |e| s += "#{dot_id(e.from.eid)} -> #{dot_id(e.to.eid)}\n" }
    s += "}"
  end

  def save_dot(filename)
    File.open(filename, "w") { |f| f.write(to_dot) }
  end

  #def reduce_size(target_size)
  #  raise "size < target_size!" if size < target_size

  #  degree = 0
  #  while size > target_size
  #    extra = size - target_size
  #    set = nodes.select { |n| n.degree == degree }
  #    set[0..([extra,set.size].min - 1)].each { |n| remove_node(n) }
  #    degree += 1
  #  end
  #end

  def reduce_size(target_size)
    raise "size < target_size!" if size < target_size

    while size > target_size
      min_degree = nodes.map{ |n| n.degree }.min
      min_degree_nodes = nodes.select { |n| n.degree == min_degree }
      n = min_degree_nodes[rand(min_degree_nodes.size)]
      remove_node(n) if n.cluster.size > 1
    end
  end

  ############ RGL interface ####################
  
  def add_edge(n1, n2)
    edge!(n1, n2)
  end
  
  def add_vertex(v)
    node!(v)
  end

  def vertices
    nodes
  end

  def in_degree(v)
    node!(v).in_degree
  end

  def out_degree(v)
    node!(v).out_degree
  end

  def each_vertex(&block)
    nodes.each { |v| block.call(v) }
  end

  def adjacent_vertices(v)
    node!(v).out_edges_map.values
  end

end

class Cluster
  # Cuidado ao alterar o eid para nao quebrar a unicidade!
  attr_accessor :data
  attr_reader :eid, :nodes
 
  def initialize(eid)
    @eid = eid
    @data = LazyHash2.new
    @nodes = Set.new
  end

  def _add(node)
    @nodes << node
  end

  def _remove(node)
    @nodes.delete(node)
  end

  def size
    @nodes.size
  end
end

class Edge
  attr_reader :from, :to
  attr_accessor :weight, :data
  
  def initialize(from, to)
    @from, @to = from, to
    @data = LazyHash2.new
  end

  def to_s
    "#{@from.to_s}->#{@to.to_s}"
  end
end

class Node
  attr_reader :cluster, :eid
  attr_reader :out_edges_map, :in_edges_map, :data
  
  def initialize(eid)
    @eid = eid
    @out_edges_map = {}
    @in_edges_map  = {}
    @data = LazyHash2.new
  end

  def to_s
    @eid
  end

  def _cluster=(cluster)
    @cluster = cluster
  end

  def out_edges
    @out_edges_map.values
  end

  def in_edges
    @in_edges_map.values
  end

  def edges
    out_edges + in_edges
  end

  def _clusters(nodes)
    nodes.map { |n| n.cluster }.uniq
  end

  def connects_to(node)
    @out_edges_map.has_key?(node)
  end

  def in_nodes; @in_edges_map.map { |n, e| n }; end
  def out_nodes; @out_edges_map.map { |n, e| n }; end
  def in_edges; @in_edges_map.values; end
  def out_edges; @out_edges_map.values; end

  def degree; neighbors.size; end
  def in_degree; @in_edges_map.size; end
  def out_degree; @out_edges_map.size; end
  def internal_degree; neighbors.select { |n| n.cluster == @cluster }.size; end
  def internal_in_degree; @in_edges_map.select { |n, e| n.cluster == @cluster }.size; end
  def internal_out_degree; @out_edges_map.select { |n, e| n.cluster == @cluster }.size ; end
  def external_degree; neighbors.select { |n| n.cluster != @cluster }.size ; end
  def external_in_degree; @in_edges_map.select { |n, e| n.cluster != @cluster }.size; end
  def external_out_degree; @out_edges_map.select { |n, e| n.cluster != @cluster }.size; end
  def cluster_span; _clusters(in_nodes + out_nodes).size; end
  def in_cluster_span; _clusters(in_nodes).size; end
  def out_cluster_span; _clusters(out_nodes).size; end

  def neighbors
    (out_edges.map { |e| e.to } + in_edges.map { |e| e.from}).uniq
  end

end

# Network in which network are labelled by numbers.
# The efficiency is improved only insignificantly.
class NumberedNetwork < Network
  attr_accessor :start_from

  def _init
    @nodes    = []
    @clusters = []
    @edges    = []
    @default_cluster = Cluster.new('DEFAULT')
    @data = LazyHash2.new
    @start_from = nil
  end

  def new_network
    return NumberedNetwork.new
  end
  
  def size
    @nodes.size - @start_from
  end

  def nodes
    @nodes[@start_from..-1]
  end

  def clusters
    @clusters
  end
end

#
# Extracted from Choice library.
#
# This class lets us get away with really bad, horrible, lazy hash accessing.
# Like so:
#   hash = LazyHash.new
#   hash[:someplace] = "somewhere"
#   puts hash[:someplace]
#   puts hash['someplace']
#   puts hash.someplace
#
# If you'd like, you can pass in a current hash when initializing to convert
# it into a lazyhash.  Or you can use the .to_lazyhash method attached to the 
# Hash object (evil!).
class LazyHash2 < Hash 
  
  # Keep the old methods around.
  alias_method :old_store, :store
  alias_method :old_fetch, :fetch
  
  # You can pass in a normal hash to convert it to a LazyHash.
  def initialize(hash = nil)
    hash.each { |key, value| self[key] = value } if !hash.nil? && hash.is_a?(Hash)
  end

  # Wrapper for []
  def store(key, value)
    self[key] = value
  end
  
  # Wrapper for []=
  def fetch(key)
    self[key]
  end

  # Store every key as a string.
  def []=(key, value)
    key = key.to_s if key.is_a? Symbol
    self.old_store(key, value)
  end
  
  # Every key is stored as a string.  Like a normal hash, nil is returned if
  # the key does not exist.
  def [](key)
    key = key.to_s if key.is_a? Symbol
    self.old_fetch(key) rescue return nil
  end

  # You can use hash.something or hash.something = 'thing' since this is
  # truly a lazy hash.
  def method_missing(meth, *args)
    meth = meth.to_s
    if meth =~ /=/
      self[meth.sub('=','')] = args.first
    else
      self[meth]
    end
  end
  
end

# Really ugly, horrible, extremely fun hack.
class Hash #:nodoc: 
  def to_lazyhash2
    return LazyHash2.new(self) 
  end
end

def read_pairs(filename=nil)
  lines = (if filename.nil?
    STDIN.readlines
  elsif filename.kind_of?(String) 
    IO.readlines(filename)
  elsif filename.kind_of?(IO)
    filename.readlines
  else
    raise Exception("Unsupported filename parameter type.")
  end)
    
  pairs = lines.map{ |line| line.strip.split(/\s+/) }
  return pairs
end

def put_pairs(pairs, filename=nil)
  if filename.nil?
    pairs.each { |x, y| puts "#{x} #{y}" }
  else
    File.open(filename, 'w') { |f| pairs.each { |x, y| f.puts "#{x} #{y}" } }
  end
end

def entities(pairs)
  pairs.flatten.uniq
end

def pairs_to_string(pairs)
  return pairs.map { |a, b| "#{a} #{b}" }.join("\n")
end

def pairs_from_string(string)
  return string.chomp.split("\n").map { |line| line.split(" ") }
end

def int_pairs_from_string(string)
  return string.chomp.split("\n").map { |line| line.split(" ").map { |x| x.chomp.to_i } }
end

# adjacency list:
# The nth-row contains the indices of nodes that are adjacent to the nth-node
# (zero-based). 
# Note that the pair's elements  must be sequential numbers starting from 0.
#
# adjacency list:
#
#  [
#   [1, 2, 3],
#   [2],
#   [],
#   [1, 2]
#  ]
#
# is equivalent to:
#  [
#   [0, 1], [0, 2], [0,3],
#   [1, 2],
#   [3, 2]
#  ]
#   
def numbered_pairs_to_adjacency_list(pairs, directed=false)
  nodes = entities(pairs).sort
  n = nodes[-1] + 1
  array = Array.new(n) { Array.new }
  pairs.each do |a, b| 
    array[a] << b
    array[b] << a if !directed
  end
  return array
end

# adjacency matrix: a NxN matrix, where N is the number of nodes
# the element i,j is 1 if there exists a pair [i, j], and 0 otherwise.
#
# Note that the pair's elements  must be sequential numbers starting from 0.
def numbered_pairs_to_adjacency_matrix(pairs, directed=false)
  nodes = entities(pairs).sort
  n = nodes[-1] + 1
  matrix = Array.new(n) { Array.new(n) { 0 } }
  pairs.each do |a, b| 
    matrix[a][b] = 1
    matrix[b][a] = 1 if !directed
  end
  return matrix
end
