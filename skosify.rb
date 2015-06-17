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
require_relative 'lib/file_parts.rb'
require_relative 'functions.rb'

available_formats = [
  {:name => 'json', :extension => 'json', :header => nil},
  {:name => 'elastic', :extension => 'json', :header => nil},
  {:name => 'xml', :extension => 'rdf', :header => $xml_header, :footer => $xml_footer},
  {:name => 'turtle', :extension => 'ttl', :header => $turtle_header, :footer => nil },
  {:name => 'triple', :extension => 'nt', :header => nil, :footer => nil}
]

$base_uri = "http://replaceme/"
$base_namespace = "unbist"
$xl = false
$id = 10000

$namespace = Hash.new
$namespace[:skos] = "http://www.w3.org/2004/02/skos/core#"
$namespace[:skosxl] = "http://www.w3.org/2008/05/skos-xl#"

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
  
  opts.on( '-f', '--format FORMAT', 'Output format. Choose: json, elastic, xml, turtle, or triple.' ) do |format|
    if format
      fidx = available_formats.find_index {|f| f[:name] == format}
      if fidx
        options[:format] = available_formats[fidx]
      else
        abort "Format #{format} is not valid."
      end
    else
      options[:format] = available_formats[2]
    end
  end
  opts.on( '-S', '--split', 'Whether or not to split the output into individual files.  Default is false.' ) do |split|
    options[:split] = true
  end
  opts.on( '--xl', 'Use SKOS-XL for the labels instead of SKOS Core.') do |xl|
    $xl = true
  end

end.parse!

if !options[:infile] then abort "Missing input file argument." end
if !options[:catdir] then abort "Missing categories directory argument." end
if !options[:outfile] then abort "Missing output file argument." end
if !options[:path] then abort "Missing output path argument." end

$resources = Array.new
$categories = Array.new
$xl_labels = Array.new

# Create ConceptScheme first
$concept_scheme = Resource.new('scheme','skos:ConceptScheme')
['ar','zh','en','fr','ru','es'].each do |language|
  if $xl
    l = Property.new($id,"UNBIS Thesaurus_#{language}",language,'skosxl:Label')
    if l.is_unique?
      $id += 1
      $xl_labels << l
      $concept_scheme.relationships << Relationship.new('skosxl:prefLabel',"_" + l.id)
    else
      # get the xl_label that was already taken
      idx = $xl_labels.find_index {|x| x.text == l.text}
      target_id = $xl_labels[idx].id
      $concept_scheme.relationships << Relationship.new('skosxl:prefLabel',"_" + target_id)
    end
  else
    $concept_scheme.labels << Property.new(nil,"UNBIS Thesaurus_#{language}",language,'skos:prefLabel')
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
          c.relationships << Relationship.new('skosxl:prefLabel',"_" + l.id)
        else
          # get the xl_label that was already taken
          idx = $xl_labels.find_index {|x| x.text == l.text}
          target_id = $xl_labels[idx].id
          c.relationships << Relationship.new('skosxl:prefLabel',"_" + target_id)
        end
      else
        c.labels << Property.new(nil,text,language,'skos:prefLabel')
      end
    end
    $categories << c
  end
end
$categories.each do |cat|
  cat.relationships << Relationship.new('skos:inScheme','scheme')
  if cat.id.size > 2
    facet = cat.id[0..1]
    parent_idx = $categories.find_index {|c| c.id == facet}
    $categories[parent_idx].relationships << Relationship.new('skos:member',"#{cat.id}")
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
  if resource.type == 'skos:Concept' || resource.type == 'unbist:PlaceName'
    map_raw_to_rel(resource)
    resource.properties.clear
  end
end

# make sure top concepts are marked as such
$resources.each do |resource|
  ridx = resource.relationships.find_index {|r| r.type == 'skos:broader'}
  unless ridx
    resource.relationships << Relationship.new('skos:topConceptOf','scheme')
    $concept_scheme.relationships << Relationship.new('skos:hasTopConcept',resource.id)
  end
end

SpinningCursor.stop

dir = "#{options[:path]}"
unless Dir.exists?(dir)
  Dir.mkdir(dir) or abort "Unable to create output directory #{dir}"
end

if options[:split]
  #write_to_individual_files
else
  write_one_big_file(options[:path],options[:format][:name],options[:outfile],options[:format][:extension],options[:format][:header],options[:format][:footer])
end