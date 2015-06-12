class Property
  attr_reader :text,:language,:type
  
  def initialize(text,language,type)
    @text = text
    @language = language
    @type = type
  end
  
  #are these necessary?
  def to_json(*a)
    
  end
  
  def to_elastic(*a)
    
  end
  
  def to_xml
    
  end
  
  def to_triple
    
  end
  
  def to_turtle
    
  end
end