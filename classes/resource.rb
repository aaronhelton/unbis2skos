################################
# Implementation Details
# name:	Resource
class Resource
  attr_reader	:id,
    :type,
		:literal,
		:routable,
		:language,
		:properties,
		:relationships

  def initialize(id,type,literal,routable,language)
    @id = id
    @type = type
    @literal = literal
    @routable = routable
    @language = language
    @properties = Array.new
    @relationships = Array.new
  end

  def add_property(property)
    @properties << property
  end

  def add_relationship(relationship)
    @relationships << relationship
  end
  
  def get_all_labels
    labels = Array.new
    @relationships.each do |rel|
      if rel.type =~ /Label/
        labels << rel.expand(rel.target)
      end
    end
    return labels.join(",")
  end

  def to_graph
    graph_q = "insert into Resource (type,literal,routable,language,properties) values ('#{@type}','#{@literal}','#{@routable}','#{@language}', { #{@properties} })"
    puts graph_q
  end
  
  def to_json(*a)
    {
      "dc:identifier" => @id,
      "rdf:type" => @type,
      "rdfs:literal" => @literal,
      "rdf:langString" => @language,
      "relationships" => @relationships
    }.to_json
  end
  
  def to_elastic(*a)
    rel_types = ["skosxl:prefLabel","skosxl:altLabel","skos:broader","skos:narrower","skos:related","skos:scopeNote","eu:domain","eu:microThesaurus"]
    
    relationships = Array.new
    
    @relationships.each do |relationship|
      if rel_types.include? relationship.type
        #ridx = $resources.find_index {|r| r.id == relationship.target}
        #labels << $resources[ridx].literal
        relationships << { :type => relationship.type, :value => relationship.expand(relationship.target) }
      end
    end
    {
      "id" => @id,
      "relationships" => relationships.uniq
    }.to_json
  end
  
  def to_xml(*a)
    
  end
  
  def to_triple
    
  end
  
  def to_turtle
    
  end
  
  def write_to_file(path,format,extension,header,footer)
    unless Dir.exists?("#{path}/#{format}")
      Dir.mkdir("#{path}/#{format}") or abort "Unable to create #{format} directory in #{path}."
    end
    unless File.exists?("#{path}/#{format}/#{@id}.#{extension}")
      File.open("#{path}/#{format}/#{@id}.#{extension}", "a+") do |file|
        file.puts(header)
        file.puts(self.send("to_#{format}".to_sym))
        file.puts(footer)
      end
    end
  end
end