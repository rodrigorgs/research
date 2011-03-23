#!/usr/bin/env ruby

require 'core/database'
Sequel::Model.plugin(:schema)

DB = Sequel.connect("sqlite:///Users/rodrigorgs/research/corpus/eclipse/git-logs/logs.db")
class Commit < Sequel::Model(:commit)
  many_to_one :project
  many_to_one :author

  set_schema do
    primary_key :id
    foreign_key :project_id #, :key => :project
    String :hash, :size => 40
    foreign_key :author_id #, :key => :author
    DateTime :time
    String :message
  end
end

class Author < Sequel::Model(:author)
  set_schema do
    primary_key :id
    String :name, :unique => true, :index => true
  end
end

class Project < Sequel::Model(:project)
  set_schema do
    primary_key :id
    String :name, :unique => true, :index => true
  end
end

class GitLogDatabase < Database
  def initialize
    #@db = Sequel.connect("sqlite://logs.db")
  end

  def create_tables
    Commit.create_table!
    Author.create_table!
    Project.create_table!
  end

  def populate_tables(glob="logs-utf8/*.txt")
    Dir.glob(glob) do |filename|
      project_name = File.basename(filename, '.txt')
      puts project_name
      project = Project.find_or_create(:name => project_name)

      IO.readlines(filename).each do |line|
        hash, author_name, time_s, message = line.chomp.split("\t")
        time = Time.parse(time_s)
      
        author = Author.find_or_create(:name => author_name)
        commit = Commit.create(:hash => hash,
            :author => author,
            :project => project,
            :time => time,
            :message => message)
      end
    end
  end
end

if __FILE__ == $0
  db = GitLogDatabase.new

  db.create_tables
  db.populate_tables("/Users/rodrigorgs/research/eclipse/git-logs/logs-utf8/*.txt")

end








