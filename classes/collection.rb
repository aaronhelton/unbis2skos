class Collection
  attr_reader :id, :uri, :labels, :in_scheme, :members

  def initialize(id, uri, labels, in_scheme)
    @id = id
    @uri = uri
    @labels = labels
    @in_scheme = in_scheme
    @members = Array.new
  end

  def add_member(uri)
    @members << uri
  end

  def to_json(*a)
    {
      "Collection" => {
        "id" => @id,
        "uri" => @uri,
        "labels" => @labels,
        "members" => @members
      }
    }.to_json(*a)
  end

  def to_xml(*a)
    xml = "<skos:Collection rdf:about=\"#{@uri}\">\n"
    @labels.each do |label|
      if label.type == 'preferred'
        xml += "  <skos:prefLabel xml:lang=\"#{label.language}\">#{label.text}</skos:prefLabel>\n"
      else
        xml += "  <skos:altLabel xml:lang=\"#{label.language}\">#{label.text}</skos:altLabel>\n"
      end
    end
    xml += "  <skos:inScheme rdf:resource=\"#{@in_scheme}\"/>\n"
    @members.each do |member|
      xml += "  <skos:member rdf:resource=\"#{member}\"/>\n"
    end
    xml += "</skos:Collection>\n"
    return xml
  end

  def to_triple(*a)
    triple = "<#{@uri}> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2004/02/skos/core#Collection> .\n"
    @labels.each do |label|
      if label.type == 'preferred'
        triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#prefLabel> \"#{label.text}\"@#{label.language} .\n"
      else
        triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#altLabel> \"#{label.text}\"@#{label.language} .\n"
      end
    end
    triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#inScheme> <#{@in_scheme}> .\n"
    @members.each do |member|
      triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#member> <#{member}> .\n"
    end
    return triple
  end

  # to do: add json-ld, turtle
  def to_turtle(*a)
    #must define @base in turtle_header below
    turtle = "<#{$base_uri}#{@id}> \n"
    turtle += "\trdf:type skos:Collection ;\n"
    @labels.each do |label|
      if label.type == 'preferred'
        turtle += "\tskos:prefLabel #{label.text.to_json}@#{label.language} ;\n"
      else
        turtle += "\tskos:altLabel #{label.text.to_json}@#{label.language} ;\n"
      end
    end
    turtle += "\tskos:inScheme <#{@in_scheme}> ;\n"
    members_array = Array.new
    @members.each do |r|
      members_array << "\tskos:member <#{r}> "
    end
    turtle += members_array.join(";\n") + ".\n"
    return turtle
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
