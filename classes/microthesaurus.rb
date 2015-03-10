################################
# Implementation Details
# name: Microthesaurus
# type: eu:MicroThesaurus
# has:	uri
#	1+ skos:prefLabel, unique for each of six xml:lang
#	0+ skos:altLabel, each assigned one xml:lang
#	1 eu:domain
#	0+ skos:hasTopConcept
class Microthesaurus
  #unclear if we really need in_scheme at this level; leaving it out for now...
  attr_reader :id, :uri, :labels, :domain, :top_concepts

  def initialize(id, uri, labels, domain)
    @id = id
    @uri = uri
    @labels = labels
    @domain = domain
    @top_concepts = Array.new
  end

  def add_top_concept(uri)
    @top_concepts << uri
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
    sql = "Resource.create([archetype_id: (Archetype.find_by name: 'MicroThesaurus').id, literal: '#{@id}'])\n"
    @labels.each do |label|
      if label.type == 'preferred'
        sql += "Resource.create([archetype_id: (Archetype.find_by name: 'prefLabel').id, literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id])\n"
        sql += "Relationship.create([subject_id: (Resource.find_by literal: '#{@id}').id, predicate_id: (Archetype.find_by name: 'prefLabel').id, object_id: (Resource.find_by literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id).id])\n"
      else
        sql += "Resource.create([archetype_id: (Archetype.find_by name: 'altLabel').id, literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id])\n"
        sql += "Relationship.create([subject_id: (Resource.find_by literal: '#{@id}').id, predicate_id: (Archetype.find_by name: 'altLabel').id, object_id: (Resource.find_by literal: #{label.text.to_json}, language_id: (Language.find_by name: '#{label.language}').id).id])\n"
      end
    end
    domain = @domain.split(/\=/).last
    sql += "Relationship.create([subject_id: (Resource.find_by literal: '#{@id}').id, predicate_id: (Archetype.find_by name: 'domain').id, object_id: (Resource.find_by literal: '#{domain}').id])\n"
    @top_concepts.each do |c|
      tid = c.split(/\=/).last
      sql += "Relationship.create([subject_id: (Resource.find_by literal: '#{@id}').id, predicate_id: (Archetype.find_by name: 'hasTopConcept').id, object_id: (Resource.find_by literal: '#{tid}').id])\n"
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
