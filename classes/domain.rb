class Domain
  #eu:domain
  # each eu:domain has zero or more eu:microthesauri
  attr_reader :id, :uri, :labels, :microthesauri, :in_scheme

  def initialize(id, uri, labels, in_scheme)
    @id = id
    @uri = uri
    @labels = labels
    @microthesauri = Array.new
    @in_scheme = in_scheme
  end

  def add_microthesaurus(uri)
    @microthesauri << uri
  end

  def to_json(*a)

  end

  #todo
  def to_jsonld(*a)

  end

  def to_xml(*a)

  end

  def to_triple(*a)

  end

  def to_turtle(*a)

  end

  def to_rails
    sql = "Resource.create([archetype_id: (Archetype.find_by name: 'Domain').id, literal: '#{@id}'])\n"
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
    @microthesauri.each do |m|
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