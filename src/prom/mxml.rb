require 'stringio'
require 'time'

# Struct technique found at http://www.devdaily.com/blog/post/ruby/how-use-struct-simplify-ruby-class-definition-declaration

class AuditTrailEntry < Struct.new(
  :task, :event_type, :timestamp, :originator)

end

class ProcessInstance < Struct.new(:identifier, :description)
  attr_reader :entries
  
  def add_entry(entry)
    @entries = [] if !entries
    @entries << entry
  end

  def new_entry(task, event_type, timestamp, originator)
    entry = AuditTrailEntry.new(task, event_type, timestamp, originator)
    add_entry(entry)
    return entry
  end

  def each_entry
    @entries.each do |e|
      yield e
    end
  end
end

class WorkflowLog
  attr_reader :instances

  def add_instance(inst)
    @instances = [] if !instances
    @instances << inst
  end

  def new_instance(identifier, description)
    inst = ProcessInstance.new(identifier, description)
    add_instance(inst)
    return inst
  end

  def each_instance
    @instances.each do |i|
      yield i
    end
  end

  def to_mxml
    s = StringIO.new
    s << <<EOT
<?xml version="1.0" encoding="UTF-8" ?>
<!-- MXML version 1.0 -->
<!-- This is a process enactment event log created to be analyzed by ProM. -->
<!-- ProM is the process mining framework. It can be freely obtained at http://www.processmining.org/. -->
<WorkflowLog xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://is.tm.tue.nl/research/processmining/WorkflowLog.xsd" description="CPN Tools simulation log">
  <Source program="CPN Tools simulation"/>
  <Process id="DEFAULT" description="Simulated process">
EOT
    each_instance do |inst|

      s << %Q{    <ProcessInstance id="#{inst.identifier}" description="#{inst.description}">\n}
      inst.each_entry do |entry|
        s << %Q{      <AuditTrailEntry>\n} 
        s << %Q{      <WorkflowModelElement>#{entry.task}</WorkflowModelElement>\n} 
        s << %Q{      <EventType>#{entry.event_type}</EventType>\n} 
        s << %Q{      <Timestamp>#{entry.timestamp.iso8601(3)}</Timestamp>\n} 
        s << %Q{      <Originator>#{entry.originator}</Originator>\n} 
        s << %Q{      </AuditTrailEntry>\n} 
      end
      s << %Q{    </ProcessInstance>\n}
    end

    s << "  </Process>\n</WorkflowLog>"
    return s.string
  end
end

if __FILE__ == $0
  # Sample code
  
  log = WorkflowLog.new
  inst = log.new_instance("1", "Simulated process")
  inst.new_entry("Register", "complete", Time.now, "System")

  print log.to_mxml
end




