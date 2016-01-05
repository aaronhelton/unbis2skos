#!/bin/env ruby
# encoding: utf-8

require 'optparse'
require 'pp'
require 'tmpdir'
require 'json'
require 'rexml/document'
require 'spinning_cursor'
require_relative 'classes/resource.rb'
require_relative 'classes/relationship.rb'
require_relative 'classes/property.rb'
require_relative 'classes/match.rb'
require_relative 'lib/file_parts.rb'
require_relative 'functions.rb'

$base_uri = "http://lib-thesaurus.un.org/thesaurus/"
$base_namespace = ":"
$xl = false
$id = 10000

$namespace = Hash.new
$namespace[:skos] = "http://www.w3.org/2004/02/skos/core#"
$namespace[:skosxl] = "http://www.w3.org/2008/05/skos-xl#"

options = {}

available_format = {:name => 'turtle', :extension => 'ttl', :header => $turtle_header, :footer => nil }

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
  
  opts.on( '-S', '--split', 'Whether or not to split the output into individual files.  Default is false.' ) do |split|
    options[:split] = true
  end
  opts.on( '--xl', 'Use SKOS-XL for the labels instead of SKOS Core.') do |xl|
    $xl = true
  end

  options[:format] = available_format

end.parse!

if !options[:infile] then abort "Missing input file argument." end
if !options[:catdir] then abort "Missing categories directory argument." end
if !options[:outfile] then abort "Missing output file argument." end
if !options[:path] then abort "Missing output path argument." end

$resources = Array.new
$categories = Array.new
$xl_labels = Array.new
$relationships = Array.new

# Create ConceptScheme first
#$concept_scheme = Resource.new('UNBISThesaurus','skos:ConceptScheme')
#['ar','zh','en','fr','ru','es'].each do |language|
#  if $xl
#    l = Property.new($id,"UNBIS Thesaurus_#{language}",language,'skosxl:Label')
#    if l.is_unique?
#      $id += 1
#      $xl_labels << l
#      r = Relationship.new('UNBISThesaurus','skosxl:prefLabel',"_" + l.id)
#      $concept_scheme.relationships << r
#      $relationships << r
#    else
      # get the xl_label that was already taken
#      idx = $xl_labels.find_index {|x| x.text == l.text}
#      target_id = $xl_labels[idx].id
#      r = Relationship.new('UNBISThesaurus','skosxl:prefLabel',"_" + target_id)
#      $concept_scheme.relationships << r
#      $relationships << r
#    end
#  else
#    $concept_scheme.labels << Property.new(nil,"UNBIS Thesaurus_#{language}",language,'skos:prefLabel')
#  end
#end
$concept_scheme = Resource.new('UNBISThesaurus','skos:ConceptScheme')
cs_file = JSON.parse(File.read("#{options[:catdir]}/00"))
cs_file.each do |cs|
  label = cs["label"]["text"]
  label_language = cs["label"]["language"]
  description = cs["description"]["text"]
  description_language = cs["description"]["language"]
  if $xl

  else
    $concept_scheme.labels << Property.new(nil,label,label_language,'skos:prefLabel')
    $concept_scheme.properties << Property.new(nil,description,description_language,'dct:description')
  end
end

# Process categories next
Dir.foreach(options[:catdir]) do |file|
  unless file == "." || file == ".." || file == "00"
    c = Resource.new(file.gsub(/\./,""),'skos:Collection')
    File.read("#{options[:catdir]}/#{file}").split(/\n/).each do |line|
      label = JSON.parse(line)
      language = label["language"]
      text = file.to_s + " - " + label["text"]
      if $xl
        l = Property.new($id, text, language, 'skosxl:Label')
        if l.is_unique?
          $id += 1
          $xl_labels << l
          r = Relationship.new(c.id,'skosxl:prefLabel',"_" + l.id)
          c.relationships << r
          $relationships << r
        else
          # get the xl_label that was already taken
          idx = $xl_labels.find_index {|x| x.text == l.text}
          target_id = $xl_labels[idx].id
          r = Relationship.new(c.id,'skosxl:prefLabel',"_" + target_id)
          c.relationships << r
          $relationships << r
        end
      else
        c.labels << Property.new(nil,text,language,'skos:prefLabel')
      end
    end
    if c.id.size > 2
      # Add an extra rdf:type via the Match class, rather than Relationship class.
      m = Match.new(c.id, 'rdf:type', 'eu:MicroThesaurus')
      c.matches << m
    else
      d = Match.new(c.id, 'rdf:type', 'eu:Domain')
      c.matches << d
    end
    $categories << c
  end
end
$categories.each do |cat|
  r = Relationship.new(cat.id,'skos:inScheme','UNBISThesaurus')
  cat.relationships << r
  $relationships << r
  if cat.id.size > 2
    facet = cat.id[0..1]
    parent_idx = $categories.find_index {|c| c.id == facet}
    r = Relationship.new(facet,'skos:member',"#{cat.id}")
    $categories[parent_idx].relationships << r
    d = Relationship.new(cat.id, 'eu:domain', facet)
    cat.relationships << d
    $relationships << r
    $relationships << d
  else
    #$concept_scheme.relationships << Relationship.new('skos:hasTopConcept',"#{cat.id}")
  end
end

# Now process concepts
puts "Parsing #{options[:infile]}"
SpinningCursor.run do
  banner "Making SDFs..."
  type :spinner
  message "Done"
end

Dir.mktmpdir do |dir|
  readfile(options[:infile],dir)
end
SpinningCursor.stop

SpinningCursor.run do
  banner "Now setting top concepts and mapping BTs, NTs, and RTs..."
  message "Done"
end

$resources.each do |resource|
  if resource.type == 'skos:Concept'
    map_raw_to_rel(resource)
    resource.properties.clear
  end
end

# make sure top concepts are marked as such
$resources.each do |resource|
  ridx = resource.relationships.find_index {|r| r.type == 'skos:broader'}
  unless ridx
    r1 = Relationship.new(resource.id,'skos:topConceptOf','UNBISThesaurus')
    r2 = Relationship.new($concept_scheme.id,'skos:hasTopConcept',resource.id)
    resource.relationships << r1
    $concept_scheme.relationships << r2
    $relationships << r1
    $relationships << r2
  end
end

SpinningCursor.stop

dir = "#{options[:path]}"
unless Dir.exists?(dir)
  Dir.mkdir(dir) or abort "Unable to create output directory #{dir}"
end

write_one_big_file(options[:path],options[:format][:name],options[:outfile],options[:format][:extension],options[:format][:header],options[:format][:footer])
