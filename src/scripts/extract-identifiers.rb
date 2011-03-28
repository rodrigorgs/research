#!/usr/bin/env ruby

=begin

Parameters:
1. Path of a local git repository containing source code
2. Path of the database where the result is to be created

=end

require 'core/database'
require 'core/scm'
require 'core/id-extractor'
require 'set' 

DB = Database.new('sqlite:///tmp/bli.db')

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
    @last_module = name 
    name = last_part(name) 
    @identifiers << Identifier.new(name, :module) 
  end 
 
  def handle_function(name, parameters, line) 
    #@last_function = {:name => name, :parameters => parameters, :line => line} 
    # Ignore constructors
    if name != @last_module
      name = last_part(name) 
      @identifiers << Identifier.new(name, :function) 
    end
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

  project_name = repo_path.split('/')[-1]

  @handlers = []
  last_identifiers = Set.new
  #doxy = DoxyParser.new(nil)
  Dir.chdir(repo_path) do

    Grit::Git::git_timeout = 90

    repo = Grit::Repo.new(repo_path)
    repo.file_filter = /\.(c|h|cpp|cxx|cc|hpp|java)$/

    #commits = repo.wanted_commits.sort_by(&:committed_date)
    commits = repo.gitlog

    num_commits = commits.size
    commits.each_with_index do |commit, commit_index|
      modified_files = commit.files_modified.select { |name| name =~ repo.file_filter }
      next if modified_files.empty?

      puts "** Checking out commit #{commit_index} / #{num_commits}"

      system("git checkout #{commit} > /dev/null 2> /dev/null")

      puts "Checked out. Parsing..."
        
      #doxy.handler = IdentifiersDoxyHandler.new 
      #doxy.parse_multiple_paths(modified_files)
      #identifiers = doxy.handler.identifiers
      identifiers = extract_ids(repo_path)
              
      puts "Parsed"
      
      new_identifiers = identifiers - last_identifiers
      last_identifiers = identifiers

      puts "Inserting #{new_identifiers.size} new identifiers..."

      developer_id = DB.insert_unique_get_pk(:developer, 
          :name => commit.author.name)
      project_id = DB.insert_unique_get_pk(:project,
          :name => project_name)
      commit_id = DB.insert_unique_get_pk(:commit,
          :project_id => project_id,
          :author_id => developer_id,
          :hash => commit.id,
          :time => commit.committed_date)
      #repofile_id = DB.insert_unique_get_pk(:repofile,
      #    :project_id => project_id,
      #    :path => nil)
      new_identifiers.each do |identifier|
        DB.insert_unique(:identifier,
          :commit_id => commit_id,
          :repofile_id => nil,
          :name => identifier)
      end

      #@handlers << doxy.handler

      #
      #puts "*********************\nCOMMIT '#{commit.message.gsub(/\n/,'')[0..50]}' by #{commit.author.name} on #{commit.committed_date.strftime('%d/%m/%Y')}"
      #if @handlers.size > 1
      #  new, old = @handlers[-1], @handlers[-2]
      #  puts "TOTAL IDs: #{new.identifiers.size}"
      #  added = new.identifiers - old.identifiers
      #  removed = old.identifiers - new.identifiers
      #  print_ids("ADDED", added)
      #  print_ids("REMOVED", removed)
      #end
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
  #extract('/Users/rodrigorgs/research/corpus/junit', nil)
  extract('/Users/rodrigorgs/local/research/corpus/eclipse/org.eclipse.mylyn', nil)
end
