# Metrics and data transformation on repositories

require 'core/util'
require 'core/scm'

class Metrics
  # repo is a Grit::Repo
  def initialize(repo)
    @repo = repo
  end

  # It's like Excel's pivot table (or OpenOffice's DataPilot)
  # Shows how often a pair (author, filename) appears in the log  
  def file_developer_table(repo)
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
  
end



