require 'set'

# from The Programmer’s Lexicon, Volume I: The Verbs
# at http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.101.1014&rep=rep1&type=pdf
verbs = %w{
  accept
  add
  check
  clear
  close
  create
  do
  dump
  end
  equals
  find
  generate
  get
  handle
  has
  hash
  init
  initialize
  insert
  is
  load
  make
  new
  next
  parse
  print
  process
  read
  remove
  reset
  set
  size
  start
  to
  update
  validade
  visit
  write
}

# additional verbs found by me
verbs += %w{
  activate
  advance
  allocate
  apply
  bind
  can
  capture
  click
  compute
  control
  dispose
  draw
  exist
  expand
  invoke
  modify
  paint
  perform
  refresh
  register
  restore
  run
  sve
  select
  store
  trim
  unselect
  validate
  save
  test
  compare
  extract
  abort
  adapt
  adjust
  allow
  append
  archive
  assert
  assign
  attach
  authenticate
}

def analyze_identifier(identifier)
  notation = nil
  
  # TODO: it's not perfect!
  if identifier =~ /^[A-Z0-9_\W]+$/
    notation = :all_caps
  elsif identifier =~ /^[a-z][0-9A-Za-z]+$/
    notation = :camel_case
  elsif identifier =~ /^[a-z0-9_\W]+$/
    notation = :delimiter_separated
  end
  
  first_word = nil
  
  if identifier =~ /^([a-z]+)/
    first_word = $1
  end
  
  return {:notation => notation,
    :first_word => first_word,
    }
end

if __FILE__ == $0
  require 'database'
  
  database = Database.new('sqlite:///tmp/bli.db')
  db = database.db
  
  ds = db[<<-EOT
    SELECT proj.name AS proj__name, id.name, id.type, dev.name as dev__name
    FROM identifier_evolution ide
    INNER JOIN identifier id ON ide.identifier_id = id.id
    INNER JOIN repofile repo ON id.repofile_id = repo.id
    INNER JOIN 'commit' com ON ide.commit_id = com.id
    INNER JOIN developer dev ON com.author_id = dev.id
    INNER JOIN project proj ON repo.project_id = proj.id
    WHERE repo.project_id = 2
    AND type = 'method'
  EOT
  ]
  
  list = Set.new
  ds.each do |row|
    identifier = row[:name]
    info = analyze_identifier(identifier)
    first_word = info[:first_word]
    
    if !verbs.include?(first_word)    
      list << {:first_word => first_word, 
        :id => row[:name], 
        :developer => row[:dev__name]}
    end
  end
  puts
  
  list.each do |word|
    p word
  end
  
  list.map{|x| x[:first_word]}.uniq.each do |first|
    puts first
  end
  
  # db[:identifier_evolution]
  #   .join(:identifier, :id => :identifier_id)
  #   .join(:repofile, :id => :repofile_id)
  #   .filter
end





