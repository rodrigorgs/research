#!/usr/bin/env ruby
require 'stringio'
require 'set'

def fn_to_array(n, &block)
  array = Array.new(n) { Array.new(n) { 0.0 } }
  0.upto(n - 1) do |i|
    (i + 1).upto(n - 1) do |j|
      array[i][j] = array[j][i] = block.call(i, j)
    end
  end
  return array
end

# x and y are vectors
def jaccard_coefficient(x, y)
  a = 0
  b_plus_c = 0
  common = x.zip(y).each do |e1, e2|
    if e1 != 0 && e2 != 0
      a += 1
    elsif e1 != 0 || e2 != 0
      b_plus_c += 1
    end
  end
  
  coef = a.to_f / (a + b_plus_c)

  return coef.nan? && 0.0 || coef
end

def extract_graph_from_doxyparse(filename)
  module_regex = "InGE::[A-Z][^:\n]*"
  dependencies = Set.new
  current_module = nil
  IO.readlines(filename).each do |line|
    if line =~ /^module (#{module_regex})$/
      current_module = $1
    elsif line =~ /^ *uses.*defined in (#{module_regex})$/
      other_module = $1
      dependencies << [current_module, other_module] unless current_module == other_module
    end
  end

  return dependencies.to_a
end

class String
  def to_dot_id
    return self.gsub(/\:/, '_')
  end

  def save_to_file(filename)
    File.open(filename, 'w') { |f| f.print(self) }
  end
end

class Array
  def save_pairs(filename)
    File.open(filename, 'w') do |f|
      self.each { |a, b| f.puts "#{a} #{b}" }
    end
  end

  def entities
    return self.flatten.uniq.sort
  end

  def to_rsf(relationship="depend")
    s = StringIO.new
    self.each { |a, b| s << "#{relationship} #{a} #{b}\n" }
    return s.string
  end
  
  # def save_rsf(filename, relationship="depend")
  #   File.open(filename, 'w') do |f|
  #     self.each { |a, b| f.puts "#{relationship} #{a} #{b}" }
  #   end    
  # end

  def to_graphviz
    s = StringIO.new
    s << "digraph G {\n"
    self.each do |a, b|
      s << "  #{a.to_dot_id} -> #{b.to_dot_id};\n"
    end
    s << "}\n"
    return s.string
  end
  
  def map_name_to_index(base_index=0)
    name_to_index = Hash.new
    self.each_with_index { |name, index| name_to_index[name] = index + base_index }
    return name_to_index
  end
  
  def to_numeric(base_index=0)
    name_to_index = self.entities.map_name_to_index(base_index)
    return self.map { |a, b| [name_to_index[a], name_to_index[b]] }
  end
  
  def to_pajek
    s = StringIO.new
    vertices = self.entities
    edges = self
    
    name_to_index = vertices.map_name_to_index
    
    s << "*Vertices #{vertices.size}\n"
    vertices.each_with_index { |name, index| s << "#{index+1} \"#{name}\"\n" }
    s << "*Edges #{edges.size}\n"
    edges.each do |x, y|
      i1, i2 = name_to_index[x], name_to_index[y]
      s << "#{i1+1} #{i2+1}\n"
    end
    return s.string
  end

  def to_adjacency_matrix(directed=true)
    nodes = self.entities
    name_to_index = nodes.map_name_to_index
    
    matrix = Array.new(nodes.size) { Array.new(nodes.size) { 0 } }
    self.each do |a, b|
      i1 = name_to_index[a]
      i2 = name_to_index[b]
      matrix[i1][i2] = 1
      matrix[i2][i1] = 1 if !directed
    end

    nodes.each_with_index do |name, index|
      matrix[index] = [name] + matrix[index] # name.to_dot_id
    end
    return matrix
  end

  # Orange's (http://www.ailab.si/orange/) tab-delimited file format
  def matrix_to_tab
    sep = "\t"
    ncols = self[0].size
    s = StringIO.new
    s << "name" + sep + 1.upto(ncols-1).map{|i| "c#{i}"}.join(sep) + "\n"
    s << Array.new(ncols){"discrete"}.join(sep) + "\n"
    s << Array.new(ncols){""}.join(sep) + "\n"
    s << self.matrix_to_csv(sep)
    return s.string
  end

  def split_matrix
    nodes = self.map {|x| x[0]}
    pure_matrix = self.map {|x| x[1..-1]}
    
    return [nodes, pure_matrix]
  end
  
  def join_matrices(nodes, pure_matrix)
    joined = []
    nodes.size.times do |i|
      joined << [nodes[i]] + pure_matrix[i]
    end
    return joined
  end

  def matrix_to_jaccard_distance
    nodes, pure_matrix = self.split_matrix
    
    jaccard_matrix = fn_to_array(nodes.size) do |i, j|
      1.0 - jaccard_coefficient(pure_matrix[i], pure_matrix[j])
    end
    
    return self.join_matrices(nodes, jaccard_matrix)
  end
  
  # Orange's (http://www.ailab.si/orange/) Distance File format
  def to_distance_file
    s = StringIO.new
    s << "#{self.size} labelled\n"
    self.size.times do |i|
      s << self[i][0..(i+1)].join("\t") + "\n"
    end
    return s.string
  end
  
  # Weka's (http://www.cs.waikato.ac.nz/ml/weka/) data file format
  def matrix_to_arff
    s = StringIO.new
    s << "@RELATION\tdependencies\n\n"
    s << "@ATTRIBUTE\tname\tstring\n"
    1.upto(self.size) { |i| s << "@ATTRIBUTE\td#{i}\tnumeric\n" }
    s << "\n@DATA\n"
    s << self.matrix_to_csv(",")
    return s.string
  end

  def matrix_to_csv(sep=",")
    return self.map { |array| array.join(sep) }.join("\n")
  end
  
  def map_node_to_module
    h = Hash[*self.map{|x|x.reverse}.flatten]
    h.default = "misc"
    return h
  end
  
  def abstract_with_modules(modules)
    node_to_module = modules.map_node_to_module
    deps = self.map { |a, b| [node_to_module[a], node_to_module[b]] }
    deps = deps.select{ |a, b| a != b }.uniq
    node_to_module.values.sort.uniq.each { |v| deps << [v, v] }
    #p deps
    return deps
  end
  
  def rename_modules_abc
    modules = self.map { |mod, node| mod }.sort.uniq
    name_to_index = modules.map_name_to_index
    return self.map { |mod, node| [(name_to_index[mod] + 65).chr, node] }.sort
  end
  
  # rename vertices, prefixing them with module name
  # returns new pairs and new modules
  def code_module_in_name(modules, separator="_")
    node_to_module = modules.map_node_to_module
    module_names = modules.sort
    new_pairs = self.map { |x| x.map { |mod, node| "#{node_to_module[mod]}#{separator}#{mod}" } }
    new_modules = modules.map { |mod, node| [mod, "#{mod}#{separator}#{node}"]}
    return [new_pairs, new_modules]
  end
  
  # convert pairs (edge) to gml
  def to_gml(modules=[])
    colors = %w{#FFFFFF #FF0000 #00FF00 #0000FF #FFFF00 #FF00FF #00FFFF #800000 #008000 #000080 #808000 #800080 #008080 #C0C0C0 #808080 #9999FF #993366 #FFFFCC #CCFFFF #660066 #FF8080 #0066CC #CCCCFF #000080 #FF00FF #FFFF00 #00FFFF #800080 #800000 #008080 #0000FF #00CCFF #CCFFFF #CCFFCC #FFFF99 #99CCFF #FF99CC #CC99FF #FFCC99 #3366FF #33CCCC #99CC00 #FFCC00 #FF9900 #FF6600 #666699 #969696 #003366 #339966 #003300 #333300 #993300 #993366 #333399 #333333}    
    
    nodes = self.entities
    node_name_to_index = nodes.map_name_to_index
    module_names = modules.map{ |x, y| x }.sort.uniq
    module_name_to_index = module_names.map_name_to_index
    node_to_module = modules.map_node_to_module
    s = StringIO.new
    s.puts 'Creator "yFiles"'
    s.puts 'Version "2.8"'
    s.puts 'graph ['
    s.puts '  hierarchic 1'
    s.puts '  label ""'
    s.puts '  directed 1'
    module_names.each_with_index do |module_name, module_index|
      module_index += 1000
      s.puts "  node ["
      s.puts "    id #{module_index}"
      s.puts "    label \"#{module_name}\""
      s.puts "    isGroup 1"
      s.puts "  ]"
    end
    nodes.each do |node|
      s.puts "  node ["
      s.puts "    id #{node_name_to_index[node]}"
      s.puts "    label \"#{node}\""
      s.puts "    graphics ["
      s.puts "      type \"ellipse\""
      s.puts "      outline \"#000000\""
      module_name = node_to_module[node]
      module_index = module_name_to_index[module_name] 
      color = module_index.nil? ? "#FFFFFF" : colors[module_index % colors.size]
      s.puts "      fill \"#{color}\""
      s.puts "    ]"
      s.puts "    gid #{module_index+1000}" if module_index
      s.puts "  ]"
    end
    self.each do |from, to|
      s.puts "  edge ["
      s.puts "    source #{node_name_to_index[from]}"
      s.puts "    target #{node_name_to_index[to]}"
      s.puts "  ]"
    end
    s.puts ']'
    return s.string
  end
  
  def to_jaccard_distance_orange
    matrix = self.to_adjacency_matrix(false)
    jaccard = matrix.matrix_to_jaccard_distance
    return jaccard.to_distance_file    
  end
  
end

################################################

def read_pairs(filename)
  IO.readlines(filename).map {|line| line.chomp.split(" ") }
end

def read_bunch_modules(filename)
  modules = []
  IO.readlines(filename).each do |line|
    mod = line.chomp.split(" = ")
    mod[1].split(", ").each { |node| modules << [mod[0], node] }
  end
  return modules
end

def read_rsf(filename)
  return read_pairs(filename).map { |a, b, c| [b, c] }
end

def read_infomap_tree_modules(filename)
  modules = []
  IO.readlines(filename).each do |line|
    if line =~ /^(\d+):\d+ .*? "(.*?)"$/
      modules << [$1, $2]
    end
  end
  return modules  
end

def read_orange_modules(filename)
  modules = []
  IO.readlines(filename).each do |line|
    if line =~ /^Cluster (\d+)\s+(.*)$/
      modules << [$1, $2]
    end
  end
  return modules
end

################################################

def export_to_multiple_formats(pairs, basename)
  pairs.save_pairs("#{basename}.pairs")
  pairs.to_graphviz.save_to_file("#{basename}.dot")
  pairs.to_rsf("depend").save_to_file("#{basename}.rsf")
  pairs.to_pajek.save_to_file("#{basename}.net")
  #puts `dot -Tpng #{basename}.dot > #{basename}.png`
  
  matrix = pairs.to_adjacency_matrix(false)
  matrix.matrix_to_tab.save_to_file("#{basename}.tab")
  
  jaccard = matrix.matrix_to_jaccard_distance
  jaccard.to_distance_file.save_to_file("#{basename}_dist.txt")
  jaccard.matrix_to_csv(",").save_to_file("#{basename}_dist_knime.csv")
  
  nodes = pairs.entities
  nodes.join("\n").save_to_file("#{basename}.nodes")

  puts "#{nodes.size} nodes and #{pairs.size} edges."
  
  return [nodes, pairs, matrix, jaccard]
end

################################################

if __FILE__ == $0
  ### 1. Extrair as dependencias.
  ### (isso já foi feito)
  
  ### 2. Converter o grafo de dependencias para o formato do programa que sera usado
  edges = read_pairs("indigente.pairs")
  
  #edges.to_rsf("depend").save_to_file("indigente.rsf") # se for usar o ACDC
  edges.to_pajek.save_to_file("indigente.net") # se for usar o Infomap (ou o Pajek)
  edges.to_jaccard_distance_orange.save_to_file("indigente_distances.txt") # se for usar o Orange
  
  #edges.to_gml.save_to_file("indigente.gml") # para visualizar com o yEd
  
  ### 3. Usar a ferramenta para realizar o agrupamento
  ### (isso é feito externamente)
  
  ### 4. Converter o agrupamento para um formato fácil de editar (RSF)
  ### (e para outros formatos de visualização)
  
  #modules = read_orange_modules("indigente_modules.tab") # se for usar o Orange
  #modules = read_bunch_modules("indigente_modules.bunch") # se for usar o Bunch
  #modules = read_rsf("indigente_modules.rsf") # se for usar o ACDC
  #modules = read_pairs("indigente_modules.pairs") # se for usar um formato simples
  modules = read_infomap_tree_modules("indigente_modules.tree") # se for usar o Infomap

  modules.to_rsf("contain").save_to_file("indigente_modules.rsf") # salva como RSF
    
  #edges.to_gml(modules).save_to_file("indigente_modules.gml") # para visualizar com o yEd
  #edges.abstract_with_modules(modules).to_gml.save_to_file("indigente_arch.gml") # para visualizar com o yEd
  
  ### 5. Editar o agrupamento encontrado para achar um agrupamento de referencia
  ### Para isso, crie uma cópia do indigente_modules.rsf (chame-a de indigente_reference.rsf)
  ### e edite-o no VIm, Notepad, TextEdit, Excel, OO Calc etc.
  
  ### 6. Comparar o agrupamento encontrado pelo algoritmo com o agrupamento de referência,
  ### usando a metrica MoJo, e visualizar o agrupamento
  
  #puts "MoJo: " + `java mojo.MoJo indigente_modules.rsf indigente_reference.rsf`
  
  #reference = read_rsf("indigente_reference.rsf")  
  #edges.to_gml(reference).save_to_file("indigente_reference.gml") # para visualizar com o yEd
  #edges.abstract_with_modules(reference).to_gml.save_to_file("indigente_reference_arch.gml") # para visualizar com o yEd  
end
