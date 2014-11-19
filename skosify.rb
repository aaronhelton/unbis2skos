#!/bin/env ruby
# encoding: utf-8

############################################################################
# To do:
#	Add select by category?
#	Limit language selections?
############################################################################

require 'optparse'
require 'pp'
require 'tmpdir'
require 'json'
require 'rexml/document'
require 'spinning_cursor'

include REXML

## Global vars
$base_uri = 'http://unbis-thesaurus.s3-website-us-east-1.amazonaws.com/?t='

##############################
## Classes
##############################

class Concept
  attr_reader :id, :uri, :labels, :in_scheme, :broader_terms, :narrower_terms, :related_terms, :scope_notes, :raw_rbnts, :collections

  def initialize(id, uri,labels,in_scheme,scope_notes, raw_rbnts)
    @id = id
    @uri = uri
    @labels = labels
    @in_scheme = in_scheme
    @broader_terms = Array.new
    @narrower_terms = Array.new
    @related_terms = Array.new
    @scope_notes = scope_notes
    #Raw RTs, BTs, and NTs for later processing, they will be discarded after
    @raw_rbnts = raw_rbnts
    #collection membership is non-transitive.  This will be a way to signal to 
    #the collections themselves what members they have	
    @collections = Array.new
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
      "Concept" => { 
        "id" => @id, 
	"uri" => @uri,
        "labels" => @labels.to_json,
        "in_scheme" => @in_scheme,
        "broader_terms" => @broader_terms,
        "narrower_terms" => @narrower_terms,
        "related_terms" => @related_terms,
        "scope_notes" => @scope_notes.to_json
      }
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
  # to do: add json-ld, turtle

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

class Scheme
  attr_reader :id, :uri, :labels, :top_concepts

  def initialize(id, uri, labels)
    @id = id
    @uri = uri
    @labels = labels
    @top_concepts = Array.new
  end

  def add_top_concept(uri)
    @top_concepts << uri
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

class Label
  attr_reader :text, :language, :type

  def initialize(text,language, type)
    @text = text.upcase
    @language = language
    @type = type
  end

  def to_json(*a)
    {
      "text" => @text,
      "language" => @language,
      "type" => @type
    }.to_json(*a)
  end
end

class ScopeNote
  attr_reader :text, :language
  
  def initialize(text,language)
    @text = text
    @language = language
  end

  def to_json(*a)
    {
      "text" => @text,
      "language" => @language
    }.to_json(*a)
  end
end


##############################
## Global Functions
##############################

def readfile(infile, scheme, exclude, pattern, tmpdir)

  concepts = Array.new

  unless File.exists?(infile) && File.readable?(infile)
    abort "Input file #{infile} does not exist or is not readable."
  end

#  tmpdir = Dir.mktmpdir or abort "Could not make a temporary directory."
  i = 0
  File.foreach(infile) do |line|
    if line !~ /:/
      # do nothing??
      i = i + 1
    else
      outfile = "#{tmpdir}/" + i.to_s
      File.open(outfile, "a") do |out|
        out.puts line
      end
    end
  end

  sdf_records_array = Array.new

  Dir.foreach(tmpdir) do |file|
    unless file == "." || file == ".."
      recordid = ""
      sdf_record_hash = Hash.new
      #puts "Reading from #{tmpdir}/#{file}"
      File.read("#{tmpdir}/#{file}").split(/\n/).each do |line|
        if line =~ /Recordid\:/
          recordid = line.split(": ")[1].gsub(/\s+/,"")
        end
        key = line.split(": ")[0].strip
        value = line.split(": ")[1].encode('UTF-8','UTF-8').strip
        sdf_record_hash.merge!(key => value)
      end
      # Now apply the pattern of explicit and implicit exclusions and inclusions
      if pattern
        unless pattern.index(sdf_record_hash["ETerm"].downcase)
          next
        end
      end
      if scheme && (sdf_record_hash["Facet"][0..(scheme.length - 1)] == scheme || sdf_record_hash["Facet"] =~ /,#{scheme}/)
        unless recordid =~ /^P/ || (!pattern && sdf_record_hash["EScope"] =~ /PROVISIONAL\ USE/) || !sdf_record_hash["ESUBFACET"] || (sdf_record_hash["GeogTerm"] == "Yes" && sdf_record_hash["PlaceName"] == "Yes") || ( exclude && ((sdf_record_hash["Facet"].split(/,/) - exclude.split(/,/)).size < sdf_record_hash["Facet"].split(/,/).size) )
          concepts << parse_raw(sdf_record_hash)
        end
      elsif !scheme
        unless recordid =~ /^P/ || (!pattern && sdf_record_hash["EScope"] =~ /PROVISIONAL\ USE/) || !sdf_record_hash["ESUBFACET"] || (sdf_record_hash["GeogTerm"] == "Yes" && sdf_record_hash["PlaceName"] == "Yes") || ( exclude && ((sdf_record_hash["Facet"].split(/,/) - exclude.split(/,/)).size < sdf_record_hash["Facet"].split(/,/).size) )
          concepts << parse_raw(sdf_record_hash)
        end
      end
    end
  end
  return concepts
end

def parse_raw(c)
  id = c["Recordid"]
  uri = "#{$base_uri}#{id}"
  labels = Array.new
  scope_notes = Array.new
  raw_rbnts = Hash.new
  labels = [	Label.new(c["ATerm"],"ar","preferred"), 
		Label.new(c["CTerm"],"zh","preferred"), 
		Label.new(c["ETerm"],"en","preferred"),
		Label.new(c["FTerm"],"fr","preferred"),
		Label.new(c["RTerm"],"ru","preferred"),
		Label.new(c["STerm"],"es","preferred")]
  in_scheme = $base_uri + "00"
  c["SearchFacet"].split(/,/).each do |s|
    collection_idx = $collections.find_index {|c| c.id == s}
    if collection_idx
      $collections[collection_idx].add_member(uri)
    end
  end
  if c["AScope"] && c["AScope"].size > 0 then scope_notes << ScopeNote.new(c["AScope"],"ar") end
  if c["CScope"] && c["CScope"].size > 0 then scope_notes << ScopeNote.new(c["CScope"],"zh") end
  if c["EScope"] && c["EScope"].size > 0 then scope_notes << ScopeNote.new(c["EScope"],"en") end
  if c["FScope"] && c["FScope"].size > 0 then scope_notes << ScopeNote.new(c["FScope"],"fr") end
  if c["RScope"] && c["RScope"].size > 0 then scope_notes << ScopeNote.new(c["RScope"],"ru") end
  if c["SScope"] && c["SScope"].size > 0 then scope_notes << ScopeNote.new(c["SScope"],"es") end

  if c["AUF"] && c["AUF"].size > 0 then labels << Label.new(c["AUF"], "ar", "alternate") end 
  if c["CUF"] && c["CUF"].size > 0 then labels << Label.new(c["CUF"], "zh", "alternate") end 
  if c["EUF"] && c["EUF"].size > 0 then labels << Label.new(c["EUF"], "en", "alternate") end 
  if c["FUF"] && c["FUF"].size > 0 then labels << Label.new(c["FUF"], "fr", "alternate") end 
  if c["RUF"] && c["RUF"].size > 0 then labels << Label.new(c["RUF"], "ru", "alternate") end 
  if c["SUF"] && c["SUF"].size > 0 then labels << Label.new(c["SUF"], "es", "alternate") end 

    raw_rbnts["RT"] = parse_rel(c["RT"])
    raw_rbnts["BT"] = parse_rel(c["BT"])
    raw_rbnts["NT"] = parse_rel(c["NT"])

  concept = Concept.new(id, uri, labels, in_scheme, scope_notes, raw_rbnts)
  return concept
end

def parse_rel(rel)
  term = Array.new
  if !rel.nil? && rel != ""
    r = rel.gsub(/,/,";").gsub(/; /,", ")
  else
    return term
  end
  if r =~ /;/
    term = r.split(/;/)
  else
    term << r
  end
  return term
end

def merge_categories(catdir)
  id = uri = nil
  collections = Array.new
  # here we are going to attempt some cleverness to keep things concise
  # first we get the Collection data from the catdir
  # then we attempt to find the Collection by id from the existing set
  # if no Collection with that id exists already, we make one
  # otherwise we update it
  # when we encounter a sub-Collection, we will want to try creating its parent
  # but only if it doesn't already exist
  Dir.foreach(catdir) do |file|
    unless file == "." || file == ".."
      id = file.gsub(/\./,"").to_s
      uri = "#{$base_uri}#{id}"
      labels = Array.new
      File.read("#{catdir}/#{file}").split(/\n/).each do |line|
        label = JSON.parse(line)
        labels << Label.new(label["text"],label["language"],"preferred")
      end
      if id.size > 2
        parent_idx = collections.find_index {|p| p.id == id[0..1]}
        if parent_idx
          #parent exists, so we just add a member to it
          collections[parent_idx].add_member(uri)
        else
          parent = Collection.new(parent_idx, nil, nil,$base_uri)
          parent.add_member(uri)
        end
      elsif id == "00"
        #skip this one because it's the ConceptScheme, not a Collection
        next
      end
      collection_idx = collections.find_index {|c| c.id == id}
      if collection_idx
        #already exists, so we can update it
        collection = collections[collection_idx]
        collection.labels = labels
        collection.uri = uri
      else
        #create it from info we have on file
        collection = Collection.new(id, uri, labels, $base_uri + "00")
        collections << collection
      end
    end
  end
  return collections
end

def create_concept_scheme(catdir)
  scheme_id = '00'
  labels = Array.new
  unless !File.exists?("#{catdir}/#{scheme_id}")
    File.read("#{catdir}/#{scheme_id}").split(/\n/).each do |line|
      label = JSON.parse(line)
      labels << Label.new(label["text"],label["language"],"preferred")
    end
  end
  concept_scheme = Scheme.new(scheme_id, $base_uri, labels)
  $concepts.each do |concept|
    concept_scheme.add_top_concept(concept.uri)
  end
  return concept_scheme
end

def show_wait_spinner(fps=10)
  chars = %w[| / - \\]
  delay = 1.0/fps
  iter = 0
  spinner = Thread.new do
    while iter do
      print chars[(iter+=1) % chars.length]
      sleep delay
      print "\b"
    end
    yield.tap{
      iter = false
      spinner.join
    }
  end
end

##############################
## Main Logic ##
##############################

options = {}

OptionParser.new do |opts|
  opts.banner = "skosify.rb takes the specified input file and transforms it into nominally SKOS compliant output, either XML or JSON."
  opts.banner += "\n\nUsage: skosify.rb [options]\n\n"
  opts.banner += "Options\n"
  
  opts.on( '-i', '--infile FILE', 'Input file' ) do |file|
    options[:infile] = file
  end

  opts.on( '-c', '--categories DIR', 'Location of the categories directory' ) do |dir|
    options[:catdir] = dir
  end

  opts.on( '-o', '--outfile FILE', 'Output file' ) do |file|
    options[:outfile] = file
  end

  opts.on( '-p', '--path DIR', 'Output directory' ) do |dir|
    options[:path] = dir
  end

  opts.on( '-s', '--scheme NAME', 'Limit by Concept Scheme' ) do |scheme|
    options[:scheme] = scheme
  end

  opts.on( '-x', '--exclude LIST', 'Comma separated list of schemes to exclude, e.g., 17.05.00,17.06.00' ) do |exclude|
    options[:exclude] = exclude
  end

  opts.on( '-a', '--pattern FILE', 'File containing a list of values by which to limit.' ) do |pattern|
    options[:pattern] = pattern
  end

  opts.on( '-f', '--format FORMAT', 'Output format. Choose: json, xml, or triple.' ) do |format|
    if format
      options[:format] = format
    else
      options[:format] = 'xml'
    end
  end
  opts.on( '-S', '--split', 'Whether or not to split the output into individual files.  Default is false.' ) do |split|
    options[:split] = true
  end


end.parse!

if !options[:infile] then abort "Missing input file argument." end
if !options[:catdir] then abort "Missing categories directory argument." end
if !options[:outfile] then abort "Missing output file argument." end
if !options[:path] then abort "Missing output path argument." end
if options[:pattern] && File.exists?(options[:pattern]) 
  pattern = (IO.readlines options[:pattern])[0].chomp.split(/,/).map!(&:downcase)
elsif options[:pattern]
  abort "Pattern file does not exist."
end

puts "Generating Collections"
$collections = merge_categories(options[:catdir]).sort_by! {|s| s.uri}

puts "Parsing #{options[:infile]}"
SpinningCursor.run do
  banner "Making SDFs..."
  type :spinner
  message "Done"
end
concepts = ''
Dir.mktmpdir do |dir|
  $concepts = readfile(options[:infile], options[:scheme], options[:exclude], pattern, dir)  
end
SpinningCursor.stop
puts "Generatuing ConceptScheme"
$concept_scheme = create_concept_scheme(options[:catdir])

SpinningCursor.run do
  banner "Now setting top concepts and mapping BTs, NTs, and RTs..."
  message "Done"
end
$concepts.each do |concept|
  if options[:scheme] && !concept.in_schemes.index("#{$base_uri}#{options[:scheme]}") 
    next
  end
  #concept.in_schemes.each do |in_scheme|
  #  scheme = concept_schemes[concept_schemes.find_index {|s| s.uri == in_scheme}]
  #  scheme.add_top_concept(concept.uri)
  #end
  if concept.raw_rbnts["RT"]
    concept.raw_rbnts["RT"].each do |rt|
      idx = $concepts.find_index{|c| c.get_id_by(rt,"en")}
      if idx
        related_concept = $concepts[idx]
        concept.add_related_term(related_concept.uri)
      end
    end
  end
  if concept.raw_rbnts["BT"]
    concept.raw_rbnts["BT"].each do |bt|
      idx = $concepts.find_index{|c| c.get_id_by(bt,"en")}
      if idx
        broader_concept = $concepts[idx]
        concept.add_broader_term(broader_concept.uri)
      end
    end
  end
  if concept.raw_rbnts["NT"]
    concept.raw_rbnts["NT"].each do |nt|
      idx = $concepts.find_index{|c| c.get_id_by(nt,"en")}
      if idx
        narrower_concept = $concepts[idx]
        concept.add_narrower_term(narrower_concept.uri)
      end
    end
  end
end
SpinningCursor.stop
dir = "#{options[:path]}"
unless Dir.exists?(dir)
  Dir.mkdir(dir) or abort "Unable to create output directory #{dir}"
end
xml_header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<rdf:RDF
  xmlns:rdfs=\"http://www.w3.org/2000/01/rdf-schema#\"
  xmlns:owl=\"http://www.w3.org/2002/07/owl#\"
  xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"
  xmlns:skos=\"http://www.w3.org/2004/02/skos/core#\"
  xmlns:dc=\"http://purl.org/dc/elements/1.1/\"
  xmlns:xsd=\"http://www.w3.org/2001/XMLSchema#\">"
xml_footer = "</rdf:RDF>"

turtle_header = "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n"
turtle_header += "@prefix skos: <http://www.w3.org/2004/02/skos/core#> .\n"
turtle_header += "@base <#{$base_uri}> .\n\n"

puts "Writing out to #{options[:path]}/#{options[:outfile]}_#{options[:format]}"
File.open("#{options[:path]}/#{options[:outfile]}_#{options[:format]}", "a+") do |file|
  if options[:format] == 'xml'
    file.puts xml_header
    #if everything above worked out, there should only be one of these
    file.puts $concept_scheme.to_xml
    if options[:split] then $concept_scheme.write_to_file(options[:path],"xml","xml", xml_header,xml_footer) end
    $collections.each do |collection|
      file.puts collection.to_xml
      if options[:split] then collection.write_to_file(options[:path],"xml","xml", xml_header,xml_footer) end
    end
    $concepts.each do |concept|
      file.puts concept.to_xml
      if options[:split] then concept.write_to_file(options[:path],"xml","xml", xml_header,xml_footer) end
    end
  elsif options[:format] == 'json'
    file.puts '{"ConceptScheme": ' + $concept_scheme.to_json
    file.puts '], "Collections":['
    file.puts $collections.collect{|collection| collection.to_json}.join(",\n")
    file.puts '], "Concepts":['
    file.puts $concepts.collect{|concept| concept.to_json}.join(",\n")
    file.puts ']}'
    if options[:split] then $concept_scheme.write_to_file(options[:path],"json","json",nil,nil) end
    $collections.each do |collection|
      if options[:split] then collection.write_to_file(options[:path],"json","json",nil,nil) end
    end
    $concepts.each do |concept|
      if options[:split] then concept.write_to_file(options[:path],"json","json",nil,nil) end
    end
  elsif options[:format] == 'triple'
    file.puts $concept_scheme.to_triple
    if options[:split] then $concept_scheme.write_to_file(options[:path],"triple","nt",nil,nil) end
    $collections.each do |collection|
      file.puts collection.to_triple
      if options[:split] then collection.write_to_file(options[:path],"triple","nt",nil,nil) end
    end
    $concepts.each do |concept|
      file.puts concept.to_triple
      if options[:split] then concept.write_to_file(options[:path],"triple","nt",nil,nil) end
    end
  elsif options[:format] == 'turtle'
    file.puts turtle_header
    file.puts $concept_scheme.to_turtle
    if options[:split] then $concept_scheme.write_to_file(options[:path], "turtle", "ttl",turtle_header,nil) end
    $collections.each do |collection|
      file.puts collection.to_turtle
      if options[:split] then collection.write_to_file(options[:path], "turtle", "ttl",turtle_header,nil) end
    end
    $concepts.each do |concept|
      file.puts concept.to_turtle
      if options[:split] then concept.write_to_file(options[:path], "turtle", "ttl",turtle_header,nil) end
    end
  end
end
