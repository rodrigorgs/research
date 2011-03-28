
require 'set'

# uses Dependency Finder -- see http://depfind.sourceforge.net/
def extract_ids(path)
  list = `ListSymbols -class-names -method-names -field-names #{path}`.split("\n")
  ids = Set.new
  
  list.each do |identifier|
    # remove $ and whatever comes after
    identifier.sub! /\$.+/, ''
    # remove java namespaces
    identifier.sub! /^.+\./, ''
    
    ids << identifier
  end
  
  return ids
end