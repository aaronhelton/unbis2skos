#!/bin/env ruby
# encoding: utf-8

require 'optparse'
require 'pp'
require 'tmpdir'
require 'json'
require 'rexml/document'
require 'spinning_cursor'
require_relative 'classes/concept.rb'
require_relative 'classes/concept_scheme.rb'
require_relative 'classes/domain.rb'
require_relative 'classes/microthesaurus.rb'
require_relative 'classes/collection.rb'
require_relative 'classes/label.rb'
require_relative 'classes/scope_note.rb'
require_relative 'functions.rb'

include REXML

## Global vars: change these to reflect the location where the final application resides
## Then re-run this script.
$base_uri = 'http://unbis-thesaurus.s3-website-us-east-1.amazonaws.com/?t='
$schema_base = 'http://unbis-thesarus.s3-website-us-east-1.amazonaws.com/schema#'

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

#puts "Generating Collections"
#$collections = merge_categories(options[:catdir]).sort_by! {|s| s.uri}

puts "Generating Domains and Microthesauri"
dmt = make_domains_and_microthesauri(options[:catdir])
$domains = dmt[0]
$microthesauri = dmt[1]
#puts $microthesauri.inspect

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

map_domains_and_microthesauri

puts "Generating ConceptScheme"
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
    #$collections.each do |collection|
    #  file.puts collection.to_xml
    #  if options[:split] then collection.write_to_file(options[:path],"xml","xml", xml_header,xml_footer) end
    #end
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
    #$collections.each do |collection|
    #  if options[:split] then collection.write_to_file(options[:path],"json","json",nil,nil) end
    #end
    $concepts.each do |concept|
      if options[:split] then concept.write_to_file(options[:path],"json","json",nil,nil) end
    end
  elsif options[:format] == 'triple'
    file.puts $concept_scheme.to_triple
    if options[:split] then $concept_scheme.write_to_file(options[:path],"triple","nt",nil,nil) end
    #$collections.each do |collection|
    #  file.puts collection.to_triple
    #  if options[:split] then collection.write_to_file(options[:path],"triple","nt",nil,nil) end
    #end
    $concepts.each do |concept|
      file.puts concept.to_triple
      if options[:split] then concept.write_to_file(options[:path],"triple","nt",nil,nil) end
    end
  elsif options[:format] == 'turtle'
    file.puts turtle_header
    file.puts $concept_scheme.to_turtle
    if options[:split] then $concept_scheme.write_to_file(options[:path], "turtle", "ttl",turtle_header,nil) end
    #$collections.each do |collection|
    #  file.puts collection.to_turtle
    #  if options[:split] then collection.write_to_file(options[:path], "turtle", "ttl",turtle_header,nil) end
    #end
    $concepts.each do |concept|
      file.puts concept.to_turtle
      if options[:split] then concept.write_to_file(options[:path], "turtle", "ttl",turtle_header,nil) end
    end
  elsif options[:format] == 'rails'
    csql = $concept_scheme.to_rails
    resource_sql = csql[0]
    relationship_sql = csql[1]
    #$collections.each do |collection|
    #  sql = collection.to_rails
    #  resource_sql += sql[0]
    #  relationship_sql += sql[1]
    #end
    $domains.each do |domain|
      sql = domain.to_rails
      resource_sql += sql[0]
      relationship_sql += sql[1]
    end
    $microthesauri.each do |mt|
      sql = mt.to_rails
      resource_sql += sql[0]
      relationship_sql += sql[1]
    end
    $concepts.each do |concept|
      sql = concept.to_rails
      resource_sql += sql[0]
      relationship_sql += sql[1]
    end
    file.puts resource_sql
    file.puts relationship_sql
  end
end
