class Resource
  attr_reader :id, :type, :labels, :scope_notes, :relationships, :properties, :rel_sql
  
  def initialize(id,type)
    @id = id
    @type = type
    @labels = Array.new
    @scope_notes = Array.new
    @relationships = Array.new
    @properties = Array.new
    @rel_sql = Array.new
  end
  
  def get_label_by(lang)
    label_idx = @labels.find_index {|l| l.language == lang}
    if label_idx
      return @labels[label_idx].text
    else
      return nil
    end
  end
  
  def get_id_by(label, lang = "en")
    if label == self.get_label_by(lang)
      return self
    else
      return nil
    end
  end
  
  def to_json(*a)
    #to do
  end
  
  def to_elastic(*a)
    #to do
  end
  
  def to_xml
    xml = "<#{@type} rdf:about=\"unbist:#{@id}\">\n"
    @labels.each do |l|
      xml += "<#{l.type} xml:lang=\"#{l.language}\">#{l.text.to_json}</#{l.type}>\n"
    end
    @scope_notes.each do |s|
      xml += "<#{s.type} xml:lang=\"#{s.language}\">#{s.text.to_json}</#{s.type}>\n"      
    end
    @relationships.each do |r|
      xml += "<#{r.type} rdf:resource=\"unbist:#{r.target}\"/>\n"
    end
    xml += "</#{@type}>"
    return xml
  end
  
  def to_triple
    type = @type.split(/\:/)
    triple = "<#{$base_uri}#{@id}> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <#{$namespace[type.first.to_sym]}#{type[1]}> .\n"
    triple_array = Array.new
    @labels.each do |l|
      t = l.type.split(/\:/)
      triple_array << "<#{$base_uri}#{@id}> <#{$namespace[t.first.to_sym]}#{t[1]}> #{l.text.to_json}@#{l.language} ."
    end
    @scope_notes.each do |s|
      t = s.type.split(/\:/)
      triple_array << "<#{$base_uri}#{@id}> <#{$namespace[t.first.to_sym]}#{t[1]}> #{s.text.to_json}@#{s.language} ."
    end
    @relationships.each do |r|
      t = r.type.split(/\:/)
      triple_array << "<#{$base_uri}#{@id}> <#{$namespace[t.first.to_sym]}#{t[1]}> <#{$base_uri}#{r.target}> ."      
    end
    triple += triple_array.join("\n")
    return triple
  end

  def to_turtle
    id = @id
    unless id == 'scheme'
      id = "_" + @id
    end
    turtle = "unbist:#{id} rdf:type #{@type} ;\n"
    turtle_array = Array.new
    @labels.each do |l|
      turtle_array << "  #{l.type} #{l.text.to_json}@#{l.language}"
    end
    @scope_notes.each do |s|
      turtle_array << "  #{s.type} #{s.text.to_json}@#{s.language}"
    end
    @relationships.each do |r|
      turtle_array << "  #{r.type} unbist:_#{r.target}".gsub(/__/,"_")
    end
    turtle += turtle_array.join(" ;\n") + " ."
    return turtle
  end
  
  def to_sql
    id = @id
    if @id == 'scheme' then id = '00' end
    sql_array = Array.new
    sql_array << "insert into thesaurus_resource (uri, resource_type) values('#{@id}','#{@type}')"
    @labels.each do |l|
      sql_array << "insert into thesaurus_property (property_source_id, property_text, property_type, property_language) values((select id from thesaurus_resource where uri = '#{@id}'), '#{l.text.gsub(/\'/,"''")}', '#{l.type}', '#{l.language}')"
    end
    @scope_notes.each do |s|
      sql_array << "insert into thesaurus_property (property_source_id, property_text, property_type, property_language) values((select id from thesaurus_resource where uri = '#{@id}'), '#{s.text.gsub(/\'/,"''")}', '#{s.type}', '#{s.language}')"
    end
    return sql_array.join(";\n") + ';'
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