#!/usr/bin/env ruby

require 'rubygems'
require 'sequel'
require 'prom/mxml'

def query_string(args)
  s = <<-EOT
    SELECT bug.bug_id, bug.creation_ts, bug.reporter,
      act.who, act.bug_when, field.name, act.added, act.removed
    FROM products prod
    INNER JOIN components comp ON comp.product_id = prod.id
    INNER JOIN bugs bug ON bug.component_id = comp.id
    INNER JOIN bugs_activity act ON act.bug_id = bug.bug_id
    INNER JOIN fielddefs field ON field.id = act.fieldid
    WHERE prod.name = '#{args[:product]}'
    AND comp.name = '#{args[:component]}'
    AND field.name = 'bug_status'
    ORDER BY bug.bug_id, bug_when
    EOT
end

product = 'Mylyn'
component = 'Core'

if (ARGV.size < 2)
  STDERR.puts "args: product component"
  STDERR.puts "Assuming product = '#{product}' and component = '#{component}'."
else
  product, component = ARGV[0..1]
end

db = Sequel.connect('mysql://root:root@localhost/bugs')
query = query_string(:product => product, :component => component)
ds = db[query]

log = WorkflowLog.new
inst = nil
counter = 0

last_bug_id = nil
ds.each do |row|
  bug_id = row[:bug_id]
  task = row[:added]
  time = row[:bug_when]
  originator = row[:who]
  
  if (bug_id != last_bug_id)
    last_bug_id = bug_id
    counter += 1
    # if (counter > 30)
    #   break
    # end
    STDERR.puts "Bug number #{bug_id}"
    
    inst = log.new_instance("#{bug_id}", "Bug n#{bug_id}")
    inst.new_entry(row[:removed], "complete", row[:creation_ts], row[:reporter])
  end
  
  inst.new_entry(task, "complete", time, originator)
end

print log.to_mxml
