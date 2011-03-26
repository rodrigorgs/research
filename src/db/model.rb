#!/usr/bin/env ruby

require 'core/database'

######################################################################
#          Database Schema        ####################################
######################################################################
# 
# Basic information about a commit, usually shown on a log
#
class Commit < Sequel::Model(:commit)
  many_to_one :project
  many_to_one :author
end
######################################################################
#
# A developer registered in some project
#
class Developer < Sequel::Model(:developer)
end
######################################################################
#
# A project under version control (a repository)
#
class Project < Sequel::Model(:project)
end
######################################################################
#
# File under version control
#
class RepoFile < Sequel::Model(:repofile)
  many_to_one :project
end
######################################################################
#
# Identifier inside a source code file
# (e.g., name of a method, name of a class...)
#
class Identifier < Sequel::Model(:identifier)
  many_to_one :repofile
end
######################################################################

class GitLogDatabase < Database
  def initialize
    #@db = Sequel.connect("sqlite://logs.db")
  end

  def create_tables
    raise Exception, 'Use Sequel Migrations instead!'
  end

  #
  # Populate commit table (and other dependent tables) based on text files containing
  # git logs formatted in a special way. These logs are created by the script
  # extract-repos.rb
  #
  def populate_tables(glob)
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

  db.populate_tables("/Users/rodrigorgs/research/eclipse/git-logs/logs-utf8/*.txt")
end








