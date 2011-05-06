# Analyzes a case and classifies it in n dimensions.
class IProcessCaseHandler
  attr_accessor :case_id
  
  def _not_implemented
    throw RuntimeError, "Method not implemented"
  end
  
  def analyze_event; _not_implemented; end  
  def n_dimensions; _not_implemented; end
  def value_for_dimension; _not_implemented; end
  def label_for_dimension; _not_implemented; end
end

# Classifies a bug into two dimensions:
#   - success: whether the bug was not reopened after its solution was verified
#   - conform: whether the person who resolved the bug is distinct from the
#              the person who verified it.
class FourEyesReopenClassifier < IProcessCaseHandler
  def initialize
    @was_reopened_after_verified = false
    @was_verified_by_the_same_person_who_resolved = false
  end
  
  # can be overriden
  def analyze_event(task, originator)
    if task == 'VERIFIED'
      @was_verified = true
      @verifier = originator
      if @verifier == @resolver
        @was_verified_by_the_same_person_who_resolved = true
      end
    elsif task == 'RESOLVED'
      @resolver = originator
    elsif task == 'REOPENED' && @was_verified
      @was_reopened_after_verified = true
    end
  end
  
  def n_dimensions
    2
  end
  
  def value_for_dimension(n)
    case n
    when 0 then !@was_reopened_after_verified
    when 1 then !@was_verified_by_the_same_person_who_resolved
    else raise RuntimeError, "Non existing dimension!"
    end
  end
  
  def label_for_dimension(n)
    case n
    when 0 then "success"
    when 1 then "conform"
    else raise RuntimeError, "Non existing dimension!"
    end
  end
  
  def classification
    ret = []
    n_dimensions.times do |i|
      ret << "#{label_for_dimension(i)}: #{value_for_dimension(i)}"
    end
    return ret
  end
end

# Handles a log, creating cases whenever necessary. Each case can be
# post-processed in method handle_case, which should be implemented
# by subclasses.
#
# After instantiation, case_class should be configured, which is the
# class used to create cases.
class IProcessLogHandler
  attr_accessor :case_class

  def initialize
    @last_case = nil
  end

  def new_case
    return @case_class.new
  end

  def handle_case(a_case)
    @confusion[a_case.classification] += 1
  end

  def analyze_task(case_id, task, originator)
    if @last_case.nil? || @last_case.case_id != case_id
      if !@last_case.nil?
        handle_case(@last_case)        
      end
      
      @last_case = new_case
      @last_case.case_id = case_id
    end
    
    @last_case.analyze_event(task, originator)
  end
end

# Counts the ocurrences of each classification given by a IProcessCaseHandler.
# The ocurrences can be accessed via the method contingency, which is a 
# sparse table.
class ProcessContigency < IProcessLogHandler
  attr_reader :contingency
  
  def initialize
    @contingency = Hash.new(0)
  end
  
  def handle_case(a_case)
    @contingency[a_case.classification] += 1
  end
end

####################################################

# reads lines from io (e.g., ARGF) and feeds them to
# the given handler (IProcessLogHandler).
def process_prom_csv(handler, io, separator=';')
  first_line = true
  io.each do |line|
    if first_line
      first_line = false
      next
    end
    
    fields = line.split(separator)[0..2]
    handler.analyze_task(*fields)    
  end
end

if __FILE__ == $0
  handler = ProcessContigency.new
  handler.case_class = FourEyesReopenClassifier
  
  process_prom_csv(handler, ARGF)
  
  p handler.contingency
end