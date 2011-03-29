require 'set'
require 'open3'

# uses Dependency Finder -- see http://depfind.sourceforge.net/
#def extract_ids(path)
#  list = `ListSymbols -class-names -method-names -field-names #{path}`.split("\n")
#  ids = Set.new
#  
#  list.each do |identifier|
#    # remove $ and whatever comes after
#    identifier.sub! /\$.+/, ''
#    # remove java namespaces
#    identifier.sub! /^.+\./, ''
#    
#    ids << identifier
#  end
#  
#  return ids
#end

def extract_ids_from_io(io, prefix_to_remove)
  len_minus_1 = prefix_to_remove.size - 1
  
  ids = Set.new
  
  io.each do |line|
    if not line =~ /.+;.+;.+/ then
      raise RuntimeError, "Invalid idextractor format."
    end
    fields = line.strip.split(";")
    filename = fields[2]
    if filename.start_with?(prefix_to_remove)
        filename.slice!(0..len_minus_1)
    end
    ids << {:name => fields[0], :type => fields[1], :file => filename}
  end
  
  return ids
end

# paths is an array of paths.
# If paths include a directory, the directory is traversed.
#
def extract_ids(paths, prefix_to_remove)
  ids = nil
  
    Open3.popen3("xargs java idextractor.Main") do |stdin, stdout, stderr|
      Thread.new do
        loop do
          out = stderr.gets
          puts out if out
        end
      end

      stdin.print(paths.join("\n"))
      stdin.close
      
      ids = extract_ids_from_io(stdout, prefix_to_remove)
    end
  
  #string = `java idextractor.Main #{paths.join(' ')}`
  #ids = extract_ids_from_io(StringIO.new(string))
  
  return ids
end