class Match
  attr_reader :source, :type, :target

  def initialize(source,type,target)
    @source = source
    @type = type
    @target = target
  end

end
