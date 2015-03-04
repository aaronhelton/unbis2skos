class Microthesaurus
  #eu:microthesaurus
  #each eu:microthesaurus belongs to exactly one eu:domain
  #unclear if we really need in_scheme at this level; leaving it out for now...
  attr_reader :id, :uri, :labels, :domain, :members

  def initialize(id, uri, labels, domain)
    @id = id
    @uri = uri
    @labels = labels
    @domain = domain
    @members = Array.new
  end

  def add_member(uri)
    @members << uri
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
