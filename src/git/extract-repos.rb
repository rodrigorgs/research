#!/usr/bin/env ruby

require 'fileutils'

def run_cmd(s)
  puts "** #{s}"
  system s
end

def create_log
  
end

if __FILE__ == $0
  file = IO.read('index.html')

  if not File.exist?('logs')
    puts "Creating folder logs"
    FileUtils.mkdir('logs')
  end

  # if not File.exist?('repo')
  #   puts "Creating folder repo"
  #   FileUtils.mkdir('repo')
  #   Dir.chdir('repo') { run_cmd 'git init' }
  # end

  Dir.glob("org.eclipse*") do |project|
    Dir.chdir(project) do
      logfile = "../logs/#{project}.txt"
      if !File.exist?(logfile)
        puts "** extracting log for #{project}"
        #run_cmd "/home/rodrigo/shared/usr/bin/git log --pretty=%H%x09%an%x09%ai%x09%s"
        #run_cmd 'ls -d ../logs'
        run_cmd "/home/rodrigo/shared/usr/bin/git log --pretty=%H%x09%an%x09%ai%x09%s > #{logfile}"
      end
    end
  end

  file.scan(%r{git://[^ <]+}) do |url|
    url =~ %r{/([^/]*).git$}
    dirname = $1
    logfile = "logs/#{dirname}.txt"
    
    if File.exist?(dirname)
      # if File.exist?(logfile)
        puts "Skipping #{dirname}"
      # else        
      # end
    else
      puts "==========="
      puts "CLONING #{dirname}"
      puts "==========="
      run_cmd "git clone #{url}"
      # run_cmd "git remote add #{dirname} #{url}"
      # run_cmd "git fetch #{dirname}"
      # run_cmd "git log #{dirname}/origin --pretty=%H%x09%an%x09%ai%x09%s > ../logs/#{filename}"
      sleep(rand*25)
    end
  
    puts
    puts
  end
end
