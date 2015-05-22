################################
# Implementation Details
# name:	Resource
class Relationship
  attr_reader :type, :target
  
  def initialize(type,target)
    @type = type
    @target = target
  end
  
  def to_json(*a)
    {
      "rdf:type" => @type,
      "rdf:resource" => @target
    }.to_json
  end
  
  def expand(target)
    expansion = nil
    if $resources 
      ridx = $resources.find_index {|r| r.id == target}
      if ridx
        t = $resources[ridx]
        if t.literal
          expansion = $resources[ridx].literal
        else
          expansion = $resources[ridx].get_all_labels
        end
      end
    else
      expansion = nil
    end
    return expansion
  end
end