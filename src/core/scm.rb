#!/usr/bin/env ruby
# Functions related to source code management.
# Currently, only GIT is supported.

require 'time'
require 'date'
require 'narray'
require 'set'
require 'grit'
require "enumerator"
require 'ostruct'

=begin Old classes and methods
# def commit_timetable(log, n_divisions)
#   commits = 
# 
#   dates = commits.map(&:date)
#   min_date = dates.min
#   max_date = dates.max + 1
#   interval_sec = (max_date - min_date) / n_divisions
#   authors = commits.map(&:author).uniq
#   author_index = create_index(authors)
# 
#   p interval_sec / (60*60*24)
# 
# #  table = Array.new(authors.size) { Array.new(n_divisions) {" "} }
#   table = NMatrix.object(n_divisions + 1, authors.size)
#   table.fill(" ")
#   table[n_divisions, 0..authors.size - 1] = authors
# 
#   commits.each do |commit|
#     timeslot = ((commit.date - min_date) / interval_sec).to_i
#     authorslot = author_index[commit.author]
#     table[timeslot, authorslot] = "X"
#   end
#   
#   return table
# end

def conta_desenvolvedores_por_arquivo
  x = []
  Dir.glob("**/*.{c,java}") do |filename|
    count = `git log  --pretty="%an" #{filename} | sort | uniq | wc -l`.to_i
    x << [filename, count]
  end

  x = x.sort_by {|_,number_developers| number_developers}.reverse
  print x.map {|l| l.join("\t")}.join("\n")
end

def lista_desenvolvedores
  return `git log --pretty=%an,%ai` #.split("\n").map(&:chomp)
end

class Commit
  attr_accessor :author, :date, :hash, :from_log
  
  def inspect
    return "#{author},#{date},#{hash}"
  end
  
  def changed_files
    Dir.chdir(from_log.directory) do
      return `git diff #{hash} --name-only`.split("\n").map(&:chomp)
    end
  end
end

class CommitLog
  attr_accessor :commit_hash, :directory

  def initialize
    commits = Hash.new
  end
  
  def commit_with_hash(h)
    return commit_hash[h]
  end
  
  def commits
    return commit_hash.values
  end
  
  def CommitLog.log_from_directory(dir='.')
    log = CommitLog.new
    log.directory = dir
    log.commit_hash = Hash.new
    p log.commit_hash
    
    Dir.chdir(dir) do
      s = `git log --pretty=%an,%ai,%H`
      s.split("\n").each do |line|
        data = line.chomp.split(",")
        commit = Commit.new
        commit.author, commit.date, commit.hash = data[0], Time.parse(data[1]), data[2]
        commit.from_log = log
        log.commit_hash[commit.hash] = commit
      end
    end

    return log
  end
  
  def authors
    self.commits.map(&:author).uniq
  end
  
  def dates
    self.commits.map(&:date).uniq
  end
end
=end

class Grit::Repo
  def gitlog
    self.log(self.branches.first.name)
  end

  def each_commit_row
    self.gitlog.each do |commit|
      yield OpenStruct.new(:id => commit.id,
          :commit => commit,
          :date => commit.date,
          :date_s => commit.date.strftime('%d/%m/%Y'),
          :author => commit.author,
          :author_s => commit.author.name)
    end
  end

  def each_file_modified_row
    self.each_commit_row do |row|
      row.commit.files_modified.each do |filename|
        row.filename = filename
        yield row
      end
    end
  end

  def commit_timetable(n_divisions)
    commits = self.gitlog
    
    dates = commits.map(&:date)
    authors = commits.map{|c| c.author.name}.uniq
    
    min_date, max_date = dates.min, dates.max
    interval_sec = (max_date - min_date) / n_divisions    
    author_index = create_index(authors)

    p interval_sec / (60*60*24)

    table = NMatrix.object(n_divisions + 1, authors.size)
    table.fill(" ")
    table[n_divisions, 0..authors.size - 1] = authors

    commits.each do |commit|
      timeslot = ((commit.date - min_date) / interval_sec).to_i
      authorslot = author_index[commit.author.name]
      table[timeslot, authorslot] = "X"
    end  
    
    return table
  end
end

class Grit::Commit
  def files_modified
    self.tree.blobs_recursive.map(&:name)
  end
end

class Grit::Tree
  def blobs_recursive
    results = []
    to_search = self.contents.dup
    while (to_search.size > 0)
      elem = to_search.pop
      if elem.kind_of?(Grit::Blob)
        results << elem
      elsif elem.kind_of?(Grit::Tree)
        elem.contents.each do |child|
          arepo = self.instance_variable_get(:@repo)
          new_child = child.class.create(arepo, :id => child.id, :mode => child.mode, :name => "#{elem.name}/#{child.name}")
          to_search << new_child
        end
      end
    end
    return results
  end
end

def create_index(array)
  h = Hash.new
  array.each_with_index { |elem, index| h[elem] = index }
  return h
end

def print_timetable(table, sep="")
  lines = table.to_a.map { |row| row.join(sep) }
  puts lines.join("\n")
end

#@dir = "/Users/rodrigorgs/research/corpus/eclipse/org.eclipse.jdt.core.tests.compiler"
@dir = "/Users/rodrigorgs/research/corpus/eclipse/org.eclipse.mylyn"
@repo = Grit::Repo.new(@dir)
Grit::Git::git_timeout = 90

def go2
  print_timetable(@repo.commit_timetable(70))
end

Frequency = Struct.new(:word, :frequency)

def sparse_table_to_table(sparse_table, default_value)
  x_values = sparse_table.keys.map{ |x| x[0] }.sort.uniq
  y_values = sparse_table.keys.map{ |x| x[1] }.sort.uniq
  
  matrix = NMatrix.object(x_values.size + 1, y_values.size + 1)
  matrix[1..x_values.size, 0] = x_values
  matrix[0, 1..y_values.size] = y_values  
  
  # sparse_table.each do |x, y|
  # end
  
  1.upto(x_values.size) do |i|
    1.upto(y_values.size) do |j|
      xname = x_values[i - 1]
      yname = y_values[j - 1]
      matrix[i, j] = sparse_table[[xname, yname]] || default_value
    end
  end
  
  return matrix
end

# It's like Excel's pivot table (or OpenOffice's DataPilot)
def file_developer_table
  freq = Hash.new(0)
  
  @repo.gitlog.each do |commit|
    commit.files_modified.each do |filename|
      freq[[commit.author.name, filename]] += 1
    end
  end
  
  return freq
end

# Files maintained by developer X are files that are frequently
# modified by X and rarely developed by other developers.
# We use tf-idf for this, where document=developer, and term=file
# TODO: test (maybe it's not working)
def files_maintained_by_developer(name)
  all_files_modified_by_developer = @repo.gitlog
      .select {|c| c.author.name == name}
      .map(&:files_modified)
      .flatten.uniq
  
  authors = @repo.gitlog.map{|commit| commit.author.name}.uniq
  
  # key: file; value: set of developers that modified file
  authors_that_modified_file = Hash.new(Set.new)
  
  tf_num = Hash.new(0) # key: (file, author); value: frequency
  tf_den = Hash.new(0) # key: author; value: number of files modified by author
  idf = Hash.new(0)
  @repo.gitlog.each do |commit|
    files_modified = commit.files_modified
    tf_den[commit.author.name] += files_modified.size
    files_modified.each do |file|
      tf_num[[file, commit.author.name]] += 1
      authors_that_modified_file[file] << commit.author.name
    end
  end
  
  # key: file; value: tf-idf
  tfidf_developer = Hash.new
  all_files_modified_by_developer.each do |file| 
    idf_file = Math.log(authors.size) / authors_that_modified_file[file].size
    tfidf_developer[file] = (tf_num[[file, name]].to_f / (tf_den[name])) * idf_file
  end

  return tfidf_developer
end

def long_table
  @repo.gitlog.each do |commit|
    commit.files_modified.each do |filename|
      puts "#{commit.id},#{commit.date.strftime('%d/%m/%Y')},#{commit.author.name},#{filename}"
    end
  end
end

MinMax = Struct.new(:minimum, :maximum)

def go
  author_min = Hash.new(Time.local(2200,12,31))
  author_max = Hash.new(Time.at(0))

  @repo.each_commit_row do |row|
    name = row.author_s
    date = row.date
    if (date < author_min[name])
      author_min[name] = date
    end
    if (date > author_max[name])
      author_max[name] = date
    end
  end
  
  array = []
  author_min.each_pair do |name, dates|
    array << [name,
        dates.strftime('%Y/%m/%d'),
        author_max[name].strftime('%Y/%m/%d')]
  end
  
  matrix = NMatrix[*array].transpose
  nth_line = lambda {|n| matrix[nil,n].to_a[0].map{|x| "\"#{x}\""}.join(",")}
  puts "gantt.info <- list(
    labels=c(#{nth_line.call(0)}),
    starts=as.POSIXct(strptime(c(#{nth_line.call(1)}), format=\"%Y/%m/%d\")),
    ends=as.POSIXct(strptime(c(#{nth_line.call(2)}), format=\"%Y/%m/%d\")),
    priotities=c(#{Array.new(author_min.size, 1).join(',')})
    )"
  puts "library(plotrix)"
  puts "gantt.chart(gantt.info)"
end

def go_old
  puts "Computing timetable:"
  t = commit_timetable(@log, 70)
  puts "Timetable:"
  print_timetable(t)
end

if __FILE__ == $0
  go
end
