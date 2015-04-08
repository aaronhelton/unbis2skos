################################
# Implementation Details
# name:	Resource
class Resource
  attr_reader	:type,
		:literal,
		:routable,
		:language,
		:properties
		:relationships

  def initialize(type,literal,routable,language)
    @type = type,
    @literal = literal,
    @routable = routable,
    @language = language,
    @properties = Array.new
    @relationships = Array.new
  end

  def add_property(property)
    @properties << property
  end

  def add_relationship(relationship)
    @relationships << relationship
  end

  #def add_domain(uri)
  #  unless @domains.include? uri
  #    @domains << uri
  #  end
  #end

  #def add_microthesaurus(uri)
  #  unless @microthesauri.include? uri
  #    @microthesauri << uri
  #  end
  #  domain_id = uri.split(/\=/).last[0..1]
  #  self.add_domain($base_uri + domain_id)
  #end

  def to_graph
    graph_q = "insert into Resource (type,literal,routable,language,properties) values ('#{@type}','#{@literal}','#{@routable}','#{@language}', { #{@properties} })"
    puts graph_q
  end

end

