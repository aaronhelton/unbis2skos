class Property
  attr_reader :id, :text,:language,:type
  
  def initialize(id,text,language,type)
    if id
      @id = id.to_s(16)
    end
    @text = text
    @language = language
    @type = type
  end
  
  #These are only necessary for SKOS-XL labels
  def is_unique?
    idx = $xl_labels.find_index {|x| x.text == @text && x.language == @language }
    if idx
      return false
    else
      return true
    end
  end
  
  def to_json(*a)
    
  end
  
  def to_elastic(*a)
    
  end
  
  def to_xml
    
  end
  
  def to_triple
    
  end
  
  def to_turtle
    turtle = ""
    turtle_array = Array.new
    turtle_array << "unbist:_#{@id.to_s} rdf:type #{@type.gsub(/pref/,"").gsub(/alt/,"")}"
    turtle_array << "  skosxl:literalForm #{@text.to_json}@#{language}"
    turtle = turtle_array.join(" ;\n") + " ."
  end
end