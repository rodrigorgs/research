require 'open3'

class DoxyParser
  attr_accessor :handler
  
  def initialize(handler)
    @handler = handler
  end

  def doxyparse_output(path)
    output = `doxyparse #{path}`
    return output
  end

  def parse_io(io)
    io.each do |line|
      if line =~ /^module (.*?)$/
        @handler.handle_module($1)
      elsif line =~ /^   function (.*?)\((.*?)\) in line (\d*)$/
        @handler.handle_function($1, $2.split(","), $3.to_i)
      elsif line =~ /^   variable (.*?) in line (\d*)$/
        @handler.handle_variable($1, $2.to_i)
      end
    end
  end

  def parse_multiple_paths(paths)
    Open3.popen3("xargs doxyparse") do |stdin, stdout, stderr|
      stdin.print(paths.join("\n"))
      stdin.close
      
      parse_io(stdout)
      print stderr.read
    end
  end
  
  def parse_path(path)
    Open3.popen3("doxyparse #{path}") do |stdin, stdout, stderr|
      parse_io(stdout)
      print stderr.read
    end
  end
end

class DefaultDoxyHandler
  def handle_module(name)
    puts "module #{name}"
  end

  def handle_function(name, parameters, line)
    puts "   function #{name}(#{parameters.join(',')}) in line #{line}"
  end

  def handle_variable(name, line)
    puts "   variable #{name} in line #{line}"
  end
end

if __FILE__ == $0
  #handler = DefaultDoxyHandler.new
  handler = IdentifiersDoxyHandler.new
  doxy = DoxyParser.new(handler)
  doxy.parse_path('/Users/rodrigorgs/research/corpus/screen-git/src')
  puts handler.identifiers.to_a.map(&:name).sort.join("\n")
end
