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

##############################
## Classes
##############################

class Concept
  attr_reader :id, :uri, :labels, :in_schemes, :broader_terms, :narrower_terms, :related_terms, :scope_notes, :raw_rbnts

  def initialize(id, uri,labels,in_schemes,scope_notes, raw_rbnts)
    @id = id
    @uri = uri
    @labels = labels
    @in_schemes = in_schemes
    @broader_terms = Array.new
    @narrower_terms = Array.new
    @related_terms = Array.new
    @scope_notes = scope_notes
    #Raw RTs, BTs, and NTs for later processing, they will be discarded after
    @raw_rbnts = raw_rbnts	
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
        "in_schemes" => @in_schemes,
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
        xml += "  <skosxl:prefLabel xml:lang=\"#{label.language}\">#{label.text}</skosxl:prefLabel>\n"
      else
        xml += "  <skosxl:altLabel xml:lang=\"#{label.language}\">#{label.text}</skosxl:altLabel>\n"
      end
    end
    @in_schemes.each do |s|
      xml += "  <skos:inScheme rdf:resource=\"#{s}\"/>\n"
    end
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
        triple += "<#{@uri}> <http://www.w3.org/2008/05/skos-xl#prefLabel> \"#{label.text}\"@#{label.language} .\n"
      else
        triple += "<#{@uri}> <http://www.w3.org/2008/05/skos-xl#altLabel> \"#{label.text}\"@#{label.language} .\n"
      end
    end
    @in_schemes.each do |s|
      triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#inScheme> <#{s}> .\n"
    end
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
      triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#scopeNote> \"#{s.text}\"@#{s.language} .\n"
    end
    return triple
  end
end

class Scheme
  attr_reader :id, :uri, :labels, :in_schemes, :top_concepts

  def initialize(id, uri, labels, in_schemes)
    @id = id
    @uri = uri
    @labels = labels
    @in_schemes = in_schemes
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
        "in_schemes" => @in_schemes,
        "top_concepts" => @top_concepts
      }
    }.to_json(*a)

  end

  def to_xml(*a)
    xml = "<skos:ConceptScheme rdf:about=\"#{@uri}\">\n"
    @in_schemes.each do |s|
      xml += "  <skos:inScheme rdf:resource=\"#{s}\"/>\n"
    end
    @labels.each do |label|
      # I really should make these Language classes
        xml += "  <skosxl:prefLabel xml:lang=\"#{label.language}\">#{label.text}</skosxl:prefLabel>\n"
    end
    @top_concepts.each do |c|
      xml += "  <skos:hasTopConcept rdf:resource=\"#{c}\"/>\n"
    end
    xml += "</skos:ConceptScheme>\n"
  end

  def to_triple(*a)
    # Make an ntriples set for this concept
    # format: <subject uri> <predicate uri> <object uri>
    # or
    # <subject uri> <predicate uri> "literal"@lang
    triple = "<#{@uri}> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2004/02/skos/core#ConceptScheme> .\n"
    @labels.each do |label|
      if label.type == 'preferred'
        triple += "<#{@uri}> <http://www.w3.org/2008/05/skos-xl#prefLabel> \"#{label.text}\"@#{label.language} .\n"
      else
        triple += "<#{@uri}> <http://www.w3.org/2008/05/skos-xl#altLabel> \"#{label.text}\"@#{label.language} .\n"
      end
    end
    @in_schemes.each do |s|
      triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#inScheme> <#{s}> .\n"
    end
    @top_concepts.each do |c|
      triple += "<#{@uri}> <http://www.w3.org/2004/02/skos/core#broader> <#{c}> .\n"
    end
    return triple
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

def readfile(infile, scheme, exclude, pattern)

  concepts = Array.new

  unless File.exists?(infile) && File.readable?(infile)
    abort "Input file #{infile} does not exist or is not readable."
  end

  tmpdir = Dir.mktmpdir or abort "Could not make a temporary directory."
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
  uri = "/unbist/concept/#{id}"
  labels = Array.new
  in_schemes = Array.new
  scope_notes = Array.new
  raw_rbnts = Hash.new
  labels = [	Label.new(c["ATerm"],"ar","preferred"), 
		Label.new(c["CTerm"],"zh","preferred"), 
		Label.new(c["ETerm"],"en","preferred"),
		Label.new(c["FTerm"],"fr","preferred"),
		Label.new(c["RTerm"],"ru","preferred"),
		Label.new(c["STerm"],"es","preferred")]
  c["SearchFacet"].split(/,/).each do |s|
    in_schemes << "/unbist/scheme/#{s[0..1]}"
    in_schemes << "/unbist/scheme/#{s}"
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

  concept = Concept.new(id, uri, labels, in_schemes, scope_notes, raw_rbnts)
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
  concept_schemes = Array.new
  Dir.foreach(catdir) do |file|
    unless file == "." || file == ".."
      id = file.gsub(/\./,"").to_s
      uri = "/unbist/scheme/#{id}"
      labels = Array.new
      in_schemes = Array.new
      File.read("#{catdir}/#{file}").split(/\n/).each do |line|
        label = JSON.parse(line)
        labels << Label.new(label["text"],label["language"],"preferred")
      end
      if id.size > 2
        in_schemes = ["/unbist/scheme/00","/unbist/scheme/#{id[0..1]}"]
      elsif id == "00"
        in_schemes = []
      else
        in_schemes = ["/unbist/scheme/00"]
      end
      #p "Making new concept scheme with id: #{id}"
      concept_scheme = Scheme.new(id, uri, labels, in_schemes)
      #p concept_scheme
      concept_schemes << concept_scheme
    end
  end
  return concept_schemes
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

  opts.on( '-f', '--format FORMAT', 'Output format. Choose: json, rdfxml, or ntriples.' ) do |format|
    if format
      options[:format] = format
    else
      options[:format] = 'rdfxml'
    end
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

puts "Parsing #{options[:infile]}"
SpinningCursor.run do
  banner "Making SDFs..."
  type :spinner
  message "Done"
end
concepts = readfile(options[:infile], options[:scheme], options[:exclude], pattern)  
SpinningCursor.stop
puts "Generating Schemes"
concept_schemes = merge_categories(options[:catdir]).sort_by! {|s| s.uri}

SpinningCursor.run do
  banner "Now setting top concepts and mapping BTs, NTs, and RTs..."
  message "Done"
end
concepts.each do |concept|
  if !concept.in_schemes.index("/unbist/schemes/#{options[:scheme]}") 
    next
  end
  concept.in_schemes.each do |in_scheme|
    scheme = concept_schemes[concept_schemes.find_index {|s| s.uri == in_scheme}]
    scheme.add_top_concept(concept.uri)
  end
  if concept.raw_rbnts["RT"]
    concept.raw_rbnts["RT"].each do |rt|
      idx = concepts.find_index{|c| c.get_id_by(rt,"en")}
      if idx
        related_concept = concepts[idx]
        concept.add_related_term(related_concept.uri)
      end
    end
  end
  if concept.raw_rbnts["BT"]
    concept.raw_rbnts["BT"].each do |bt|
      idx = concepts.find_index{|c| c.get_id_by(bt,"en")}
      if idx
        broader_concept = concepts[idx]
        concept.add_broader_term(broader_concept.uri)
      end
    end
  end
  if concept.raw_rbnts["NT"]
    concept.raw_rbnts["NT"].each do |nt|
      idx = concepts.find_index{|c| c.get_id_by(nt,"en")}
      if idx
        narrower_concept = concepts[idx]
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
puts "Writing out to #{options[:path]}/#{options[:outfile]}_#{options[:format]}"
File.open("#{options[:path]}/#{options[:outfile]}_#{options[:format]}", "a+") do |file|
  if options[:format] == 'rdfxml'
    file.puts '<?xml version="1.0" encoding="UTF-8"?>'
    file.puts '<rdf:RDF'
    file.puts '  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"'
    file.puts '  xmlns:owl="http://www.w3.org/2002/07/owl#"'
    file.puts '  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"'
    file.puts '  xmlns:skos="http://www.w3.org/2004/02/skos/core#"'
    file.puts '  xmlns:skosxl="http://www.w3.org/2008/05/skos-xl#"'
    file.puts '  xmlns:dc="http://purl.org/dc/elements/1.1/"'
    file.puts '  xmlns:xsd="http://www.w3.org/2001/XMLSchema#">'
    concept_schemes.each do |scheme|
      file.puts scheme.to_xml
    end
    concepts.each do |concept|
      file.puts concept.to_xml
    end
    file.puts "</rdf:RDF>"
  elsif options[:format] == 'json'
    file.puts '{"ConceptSchemes":['
    concept_schemes.each do |scheme|
      file.puts scheme.to_json
    end
    file.puts '], "Concepts":['
    concepts.each do |concept|
      file.puts concept.to_json
    end
    file.puts ']}'
  elsif options[:format] == 'ntriples'
    concept_schemes.each do |scheme|
      file.puts scheme.to_triple
    end
    concepts.each do |concept|
      file.puts concept.to_triple
    end
  end
end