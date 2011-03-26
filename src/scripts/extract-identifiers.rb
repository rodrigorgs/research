#!/usr/bin/env ruby

=begin

Parameters:
1. Path of a local git repository containing source code
2. Path of the database where the result is to be created

=end

require 'core/doxyparse'
require 'core/scm'
require 'git/database'

require 'set' 

class IdentifiersDoxyHandler 
  attr_reader :identifiers 
 
  Identifier = Struct.new(:name, :type) 
 
  def initialize 
    @identifiers = Set.new 
  end 
 
  def last_part(name) 
    # for C namespaces 
    return name.split("::")[-1] 
  end 
 
  def handle_module(name) 
    #@last_module = name 
    name = last_part(name) 
    @identifiers << Identifier.new(name, :module) 
  end 
 
  def handle_function(name, parameters, line) 
    #@last_function = {:name => name, :parameters => parameters, :line => line} 
    name = last_part(name) 
    @identifiers << Identifier.new(name, :function) 
  end 
 
  def handle_variable(name, line) 
    name = last_part(name) 
    @identifiers << Identifier.new(name, :variable) 
  end 
end 

def print_ids(title, array)
  #puts "#{title}:\n" + array.map {|id| "  #{id.name} (#{id.type})"}.join("\n") if array.size > 0
  puts array.map {|id| "  ADDED #{id.name} (#{id.type})"}.join("\n") if array.size > 0
end

def extract(repo_path, db_path)
  #db = Sequel.connect("sqlite://#{db_path}")
  @handlers = []
  doxy = DoxyParser.new(nil)
  Dir.chdir(repo_path) do
 
    repo = Grit::Repo.new(repo_path)
    repo.file_filter = /\.(c|h|cpp|cxx|cc|hpp|java)$/

    #commits = repo.wanted_commits
    commits = repo.gitlog
    puts "#{commits.size} commits"
    commits.each do |commit|
      modified_files = commit.files_modified.select { |name| name =~ repo.file_filter }
      next if modified_files.empty?
      system("git checkout #{commit} > /dev/null 2> /dev/null")

      doxy.handler = IdentifiersDoxyHandler.new 
      paths = "#{modified_files.join(' ')}"
      doxy.parse_path(paths)
      @handlers << doxy.handler

      puts "*********************\nCOMMIT '#{commit.message.gsub(/\n/,'')[0..50]}' by #{commit.author.name} on #{commit.committed_date.strftime('%d/%m/%Y')}"
      if @handlers.size > 1
        new, old = @handlers[-1], @handlers[-2]
        puts "TOTAL IDs: #{new.identifiers.size}"
        added = new.identifiers - old.identifiers
        removed = old.identifiers - new.identifiers
        print_ids("ADDED", added)
        print_ids("REMOVED", removed)
      end
    end

  end

  # parse each modifiled file
  # get identifiers
end

if __FILE__ == $0
  #db = GitLogDatabase.new
  #extract('/Users/rodrigorgs/research/corpus/screen-git', '/tmp/bli.sqlite')
  #extract('/Users/rodrigorgs/research/corpus/aolserver', nil)
  #extract('/Users/rodrigorgs/research/corpus/gnash', nil)
  extract('/Users/rodrigorgs/research/corpus/junit', nil)

end
