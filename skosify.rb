#!/bin/env ruby

############################################################################
# To do:
#	serialize concept labels as JSON
#	add alternate labels
#	finish format handling (XML, JSON, both)
############################################################################

require 'optparse'
require 'pp'
require 'tmpdir'
require 'json'
require 'rexml/document'

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
        "labels" => @labels,
        "in_schemes" => @in_schemes,
        "broader_terms" => @broader_terms,
        "narrower_terms" => @narrower_terms,
        "related_terms" => @related_terms,
        "scope_notes" => @scope_notes
      }
    }.to_json(*a)
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
end

class Label
  attr_reader :text, :language

  def initialize(text,language)
    @text = text
    @language = language
  end
end

class ScopeNote
  attr_reader :text, :language
  
  def initialize(text,language)
    @text = text
    @language = language
  end
end


##############################
## Global Functions
##############################

def readfile(infile)

  concepts = Array.new

  unless File.exists?(infile) && File.readable?(infile)
    abort "Input file #{infile} does not exist or is not readable."
  end

  tmpdir = Dir.mktmpdir or abort "Could not make a temporary directory."
  p "Writing SDF files to #{tmpdir}."
  print "["
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
    if i > 1000 && i % 1000 == 0 then print "." end
  end
  p "]"

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
      unless recordid =~ /^P/ || sdf_record_hash["GeogTerm"] == "Yes" || sdf_record_hash["EScope"] =~ /PROVISIONAL\ USE/ || !sdf_record_hash["ESUBFACET"] 
        concepts << parse_raw(sdf_record_hash)
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
  labels = [	Label.new(c["ATerm"],"ar"), 
		Label.new(c["CTerm"],"zh"), 
		Label.new(c["ETerm"].downcase,"en"),
		Label.new(c["FTerm"].downcase,"fr"),
		Label.new(c["RTerm"],"ru"),
		Label.new(c["STerm"],"es")]
  c["SearchFacet"].split(/,/).each do |s|
    in_schemes << "/unbist/scheme/#{s[0..1]}"
    in_schemes << "/unbist/scheme/#{s}"
  end
  if c["AUF"] && c["AUF"].size > 0 then scope_notes << ScopeNote.new(c["AUF"],"ar") end
  if c["CUF"] && c["CUF"].size > 0 then scope_notes << ScopeNote.new(c["CUF"],"zh") end
  if c["EUF"] && c["EUF"].size > 0 then scope_notes << ScopeNote.new(c["EUF"],"en") end
  if c["FUF"] && c["FUF"].size > 0 then scope_notes << ScopeNote.new(c["FUF"],"fr") end
  if c["RUF"] && c["RUF"].size > 0 then scope_notes << ScopeNote.new(c["RUF"],"ru") end
  if c["SUF"] && c["SUF"].size > 0 then scope_notes << ScopeNote.new(c["SUF"],"es") end

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
        labels << label
      end
      if id.size > 2
        in_schemes = ["/unbist","/unbist/#{id[0..1]}"]
      elsif id == "00"
        in_schemes = []
      else
        in_schemes = ["/unbist"]
      end
      #p "Making new concept scheme with id: #{id}"
      concept_scheme = Scheme.new(id, uri, labels, in_schemes)
      #p concept_scheme
      concept_schemes << concept_scheme
    end
  end
  return concept_schemes
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

  opts.on( '-p', '--path DIRECTORY', 'Output path prefix (dir)' ) do |dir|
    options[:path] = dir
  end

  opts.on( '-f', '--format FORMAT', 'Output format: json, xml, or both' ) do |format|
    options[:format] = format
  end
end.parse!

if !options[:infile] then abort "Missing input file argument." end
if !options[:catdir] then abort "Missing categories directory argument." end
if !options[:outfile] then abort "Missing output file argument." end
if !options[:path] then abort "Missing destination path argument." end
if !options[:format] then abort "Missing output format argument." end

puts "Parsing #{options[:infile]}"
concepts = readfile(options[:infile])  
puts "Generating Schemes"
concept_schemes = merge_categories(options[:catdir]).sort_by! {|s| s.uri}
#pp concept_schemes
puts "Now setting top concepts and mapping BTs, NTs, and RTs"
concepts.each do |concept|
  concept.in_schemes.each do |in_scheme|
    scheme = concept_schemes[concept_schemes.find_index {|s| s.uri == in_scheme}]
    scheme.add_top_concept(concept.uri)
  end
  if concept.raw_rbnts["RT"]
    concept.raw_rbnts["RT"].each do |rt|
      idx = concepts.find_index{|c| c.get_id_by(rt.downcase,"en")}
      if idx
        related_concept = concepts[idx]
        concept.add_related_term(related_concept.uri)
      end
    end
  end
  if concept.raw_rbnts["BT"]
    concept.raw_rbnts["BT"].each do |bt|
      idx = concepts.find_index{|c| c.get_id_by(bt.downcase,"en")}
      if idx
        broader_concept = concepts[idx]
        concept.add_broader_term(broader_concept.uri)
      end
    end
  end
  if concept.raw_rbnts["NT"]
    concept.raw_rbnts["NT"].each do |nt|
      idx = concepts.find_index{|c| c.get_id_by(nt.downcase,"en")}
      if idx
        narrower_concept = concepts[idx]
        concept.add_narrower_term(narrower_concept.uri)
      end
    end
  end
end

p "Making JSONs in #{options[:path]}/jsons"
dirs = ["#{options[:path]}","#{options[:path]}/jsons","#{options[:path]}/jsons/scheme","#{options[:path]}/jsons/concept"]
dirs.each do |dir|
  unless Dir.exists?(dir)
    Dir.mkdir(dir) or abort "Unable to create output directory #{dir}"
  end
end
concept_schemes.each do |scheme|
  File.open("#{options[:path]}/jsons/scheme/#{scheme.id}.json", "w+") do |file|
    file.puts scheme.to_json
  end
end
concepts.each do |concept|
  File.open("#{options[:path]}/jsons/concept/#{concept.id}.json", "w+") do |file|
    file.puts concept.to_json
  end
end

