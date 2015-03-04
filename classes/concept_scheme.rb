class Scheme
  attr_reader :id, :uri, :labels, :top_concepts, :domains

  def initialize(id, uri, labels)
    @id = id
    @uri = uri
    @labels = labels
    @top_concepts = Array.new
    @domains = Array.new
  end

  def add_top_concept(uri)
    @top_concepts << uri
  end

  def add_domain(uri)
    @domains << uri
  end

  def to_json(*a)
    {
      "ConceptScheme" => {
        "id" => @id,
        "uri" => @uri,
        "labels" => @labels,
        "top_concepts" => @top_concepts
      }
    }.to_json(*a)

  end

  def to_xml(*a)
    xml = "<skos:ConceptScheme rdf:about=\"#{@uri}\">\n"
    @labels.each do |label|
      # I really should make these Language classes
        xml += "  <skos:prefLabel xml:lang=\"#{label.language}\">#{label.text}</skos:prefLabel>\n"
    end
    @top_concepts.each do |c|
      xml += "  <skos:hasTopConcept rdf:resource=\"#{c}\"/>\n"
    end
    xml += "</skos:ConceptScheme>\n"
    return xml
  end

  def to_triple(*a)
    # Make an ntriples set for this concept
    # format: <subject uri> <predicate uri> <object uri>
    # or
    # <subject uri> <predicate uri> "literal"@lang
    triple = "<#{@uri}> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2004/02/skos/core#ConceptScheme> .\n"
    @labels.each do |label|
      if label.type == 'preferred'
        triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#prefLabel> \"#{label.text}\"@#{label.language} .\n"
      else
        triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#altLabel> \"#{label.text}\"@#{label.language} .\n"
      end
    end
    @top_concepts.each do |c|
      triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#hasTopConcept> <#{c}> .\n"
    end
    return triple
  end

  def to_turtle(*a)
    #must define @base in turtle_header below
    turtle = "<#{$base_uri}#{@id}> \n"
    turtle += "\trdf:type skos:ConceptScheme ;\n"
    @labels.each do |label|
      if label.type == 'preferred'
        turtle += "\tskos:prefLabel #{label.text.to_json}@#{label.language} ;\n"
      else
        turtle += "\tskos:altLabel #{label.text.to_json}@#{label.language} ;\n"
      end
    end
    topconcepts_array = Array.new
    @top_concepts.each do |r|
      topconcepts_array << "\tskos:hasTopConcept <#{r}> "
    end
    turtle += topconcepts_array.join(";\n") + ".\n"
    return turtle
  end

  def to_rails
    sql = "Resource.create([archetype_id: (Archetype.find_by name: 'ConceptScheme').id, literal: '#{@id}'])\n"
    @labels.each do |label|
      if label.type == 'preferred'
        sql += "Resource.create([archetype_id: (Archetype.find_by name: 'prefLabel').id, literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id])\n"
        sql += "Relationship.create([   subject_id: (Resource.find_by literal: '#{@id}').id,
                                        predicate_id: (Archetype.find_by name: 'prefLabel').id, 
                                        object_id: (Resource.find_by literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id).id])\n"
      else
        sql += "Resource.create([archetype_id: (Archetype.find_by name: 'altLabel').id, literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id])\n"
        sql += "Relationship.create([   subject_id: (Resource.find_by literal: '#{@id}').id,
                                        predicate_id: (Archetype.find_by name: 'altLabel').id, 
                                        object_id: (Resource.find_by literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id).id])\n"
      end
    end
    @domains.each do |d|
      #
    end
    return sql
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
