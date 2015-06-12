class Relationship
  attr_reader :type,:target
  
  def initialize(type,target)
    @type = type
    @target = target
  end
end