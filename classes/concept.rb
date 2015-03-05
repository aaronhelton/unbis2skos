################################
# Implementation Details
# name:	Concept
# type:	skos:Concept
# has: 	uri
#	1+ skos:prefLabel for each xml:lang
#	1 skos:notation
#	1 owl:sameAs matching local URI with original UNBIS Thesaurus
#	1+ eu:microthesaurus
#	1+ eu:domain
#	1 skos:inScheme
#	0+ skos:scopeNote, each with xml:lang
#	0+ skos:broader
#	0+ skos:narrower
#	0+ skos:related
#	0+ skos:exactMatch
#	0+ skos:broadMatch
#	0+ skos:narrowMatch
#	0+ skos:relatedMatch
#	0+ skos:closeMatch
class Concept
  attr_reader   :id,
                :uri,
                :owl_sameas,
                :notation,
                :labels,
                :in_scheme, 
                :broader_terms, 
                :narrower_terms, 
                :related_terms,
                :scope_notes, 
                :raw_rbnts,
                :domains, 
                :microthesauri,
		:exact_matches,
		:close_matches,
		:narrow_matches,
		:broad_matches,
		:related_matches

  def initialize(id, uri, owl_sameas, notation, labels,in_scheme,scope_notes, raw_rbnts)
    @id = id
    @uri = uri
    @owl_sameas = owl_sameas 
    @notation = notation 
    @labels = labels
    @in_scheme = in_scheme
    @broader_terms = Array.new
    @narrower_terms = Array.new
    @related_terms = Array.new
    @scope_notes = scope_notes
    #Raw RTs, BTs, and NTs for later processing, they will be discarded after
    @raw_rbnts = raw_rbnts
    #Since collection membership doesn't extend to the concept level, we need a way to 
    #account for it. SKOS provides no explicit rules, so we are going to use EuroVoc's 
    #specification for Domains and Microthesauri as a basis for our own means of organization. 
    #See http://eurovoc.europa.eu/drupal/?q=node/555 for more details
    @domains = Array.new
    @microthesauri = Array.new
    @exact_matches = Array.new
    @close_matches = Array.new
    @narrow_matches = Array.new
    @broad_matches = Array.new
    @related_matches = Array.new
  end

  def add_related_term(uri)
    @related_terms << uri
  end

  def add_broader_term(uri)
    @broader_terms << uri
  end

  def add_narrower_term(uri)
    @narrower_terms << uri
  end

  def add_domain(uri)
    @domains << uri
  end

  def add_microthesaurus(uri)
    @microthesauri << uri
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
    {
        "id" => @id,
        "uri" => @uri,
        "labels" => @labels.to_json,
        "in_scheme" => @in_scheme,
        "broader_terms" => @broader_terms,
        "narrower_terms" => @narrower_terms,
        "related_terms" => @related_terms,
        "domains" => @domains,
        "microthesari" => @microthesauri,
        "scope_notes" => @scope_notes.to_json
    }.to_json(*a)
  end

  def to_xml(*a)
    xml = "<skos:Concept rdf:about=\"#{@uri}\">\n"
    xml += "  <skos:externalId>#{@id}</skos:externalId>\n"
    @labels.each do |label|
      if label.type == 'preferred'
        xml += "  <skos:prefLabel xml:lang=\"#{label.language}\">#{label.text}</skos:prefLabel>\n"
      else
        xml += "  <skos:altLabel xml:lang=\"#{label.language}\">#{label.text}</skos:altLabel>\n"
      end
    end
    xml += "  <skos:inScheme rdf:resource=\"#{@in_scheme}\"/>\n"
    @broader_terms.each do |b|
      xml += "  <skos:broader rdf:resource=\"#{b}\"/>\n"
    end
    @narrower_terms.each do |n|
      xml += "  <skos:narrower rdf:resource=\"#{n}\"/>\n"
    end
    @related_terms.each do |r|
      xml += "  <skos:related rdf:resource=\"#{r}\"/>\n"
    end
    @scope_notes.each do |s|
      xml += "  <skos:scopeNote xml:lang=\"#{s.language}\">#{s.text}</skos:scopeNote>\n"
    end
    xml += "</skos:Concept>\n"
    return xml
  end

  def to_triple(*a)
    # Make an ntriples set for this concept
    # format: <subject uri> <predicate uri> <object uri>
    # or
    # <subject uri> <predicate uri> "literal"@lang
    triple = "<#{@uri}> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2004/02/skos/core#Concept> .\n"
    @labels.each do |label|
      if label.type == 'preferred'
        triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#prefLabel> #{label.text.to_json}@#{label.language} .\n"
      else
        triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#altLabel> #{label.text.to_json}@#{label.language} .\n"
      end
    end
    triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#inScheme> <#{@in_scheme}> .\n"
    @broader_terms.each do |b|
      triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#broader> <#{b}> .\n"
    end
    @narrower_terms.each do |n|
      triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#narrower> <#{n}> .\n"
    end
    @related_terms.each do |r|
      triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#related> <#{r}> .\n"
    end
    @scope_notes.each do |s|
      triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#scopeNote> #{s.text.to_json}@#{s.language} .\n"
    end
    return triple
  end

  def to_turtle(*a)
    turtle_array = Array.new
    turtle = "<#{$base_uri}#{@id}> \n"
    turtle += "\trdf:type skos:Concept ;\n"
    @labels.each do |label|
      if label.type == 'preferred'
        turtle_array << "\tskos:prefLabel #{label.text.to_json}@#{label.language} "
      else
        turtle_array << "\tskos:altLabel #{label.text.to_json}@#{label.language} "
      end
    end
    turtle_array << "\tskos:inScheme <#{@in_scheme}> "
    @broader_terms.each do |b|
      turtle_array << "\tskos:broader <#{b}> "
    end
    @narrower_terms.each do |n|
      turtle_array << "\tskos:narrower <#{n}> "
    end
    @related_terms.each do |r|
      turtle_array << "\tskos:related <#{r}> "
    end
    sn_array = Array.new
    @scope_notes.each do |s|
      turtle_array << "\tskos:scopeNote #{s.text.to_json}@#{s.language} "
    end
    turtle += turtle_array.join(";\n") + ".\n"
    return turtle
  end

  def to_rails
    sql = "Resource.create([archetype_id: (Archetype.find_by name: 'Concept').id, literal: '#{@id}'])\n"
    @labels.each do |label|
      if label.type == 'preferred'
        sql += "Resource.create([archetype_id: (Archetype.find_by name: 'prefLabel').id, literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id])\n"
        sql += "Relationship.create([subject_id: (Resource.find_by literal: '#{@id}').id, predicate_id: (Archetype.find_by name: 'prefLabel').id, object_id: (Resource.find_by literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id).id])\n"
      else
        sql += "Resource.create([archetype_id: (Archetype.find_by name: 'altLabel').id, literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id])\n"
        sql += "Relationship.create([subject_id: (Resource.find_by literal: '#{@id}').id, predicate_id: (Archetype.find_by name: 'altLabel').id, object_id: (Resource.find_by literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id).id])\n"
      end
    end
    @broader_terms.each do |b|
      tid = b.split(/\//).last
      sql += "Resource.create([archetype_id: (Archetype.find_by name: 'broader').id, literal: '#{tid}'])"
      sql += "Relationship.create([subject_id: (Resource.find_by literal: '#{@id}').id, predicate_id: (Archetype.find_by name: 'broader').id, object_id: (Resource.find_by literal: #{tid}])"
    end
    @narrower_terms.each do |n|
      tid = b.split(/\//).last
      sql += "Resource.create([archetype_id: (Archetype.find_by name: 'narrower').id, literal: '#{tid}'])"
      sql += "Relationship.create([subject_id: (Resource.find_by literal: '#{@id}').id, predicate_id: (Archetype.find_by name: 'narrower').id, object_id: (Resource.find_by literal: #{tid}])"
    end
    @related_terms.each do |r|
      tid = b.split(/\//).last
      sql += "Resource.create([archetype_id: (Archetype.find_by name: 'related').id, literal: '#{tid}'])"
      sql += "Relationship.create([subject_id: (Resource.find_by literal: '#{@id}').id, predicate_id: (Archetype.find_by name: 'related').id, object_id: (Resource.find_by literal: #{tid}])"
    end
    @scope_notes.each do |s|
      #todo
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

