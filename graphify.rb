#!/bin/env ruby
# encoding: utf-8

require 'optparse'
require 'pp'
require 'tmpdir'
require 'json'
require 'spinning_cursor'
require_relative 'classes/resource.rb'
require_relative 'classes/relationship.rb'
require_relative 'lib/file_parts.rb'
require_relative 'functions.rb'

available_formats = [
  {:name => 'json', :extension => 'json', :header => nil},
  {:name => 'elastic', :extension => 'json', :header => nil},
  {:name => 'xml', :etension => 'rdf', :header => $xml_header, :footer => $xml_footer},
  {:name => 'turtle', :extension => 'ttl', :header => $turtle_header, :footer => nil },
  {:name => 'triple', :extension => 'nt', :header => nil, :footer => nil}
]

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

end.parse!

if !options[:infile] then abort "Missing input file argument." end
if !options[:catdir] then abort "Missing categories directory argument." end
if !options[:outfile] then abort "Missing output file argument." end
if !options[:path] then abort "Missing output path argument." end

$resources = Array.new
$categories = Array.new

# Create ConceptScheme first
$concept_scheme = Resource.new('00','skos:ConceptScheme',nil,true,nil)
['ar','zh','en','fr','ru','es'].each do |language|
  r = Resource.new("00-label-#{language}","skosxl:Label","UNBIS Thesaurus",false,"#{language}")
  $resources << r
  $concept_scheme.add_relationship(Relationship.new('skosxl:prefLabel',"00-label-#{language}"))
end

# Process categories next
Dir.foreach(options[:catdir]) do |file|
  unless file == "." || file == ".." || file == "00"
    c = nil
    if file.size == 2
      c = Resource.new(file,'eu:Domain',nil,true,nil)
    else
      c = Resource.new(file,'eu:MicroThesaurus',nil,true,nil)
    end
    File.read("#{options[:catdir]}/#{file}").split(/\n/).each do |line|
      label = JSON.parse(line)
      language = label["language"]
      text = label["text"]
      r = Resource.new("#{file}-label-#{language}","skosxl:Label","#{text}",false,"#{language}")
      $resources << r
      c.add_relationship(Relationship.new('skosxl:prefLabel',"#{file}-label-#{language}"))
      $categories << c
    end
  end
end
$categories.each do |cat|
  cat.add_relationship(Relationship.new('skos:inScheme','00'))
  if cat.id.size > 2
    facet = cat.id[0..1]
    parent_idx = $categories.find_index {|c| c.id == facet}
    $categories[parent_idx].add_relationship(Relationship.new('eu:microthesaurus',"#{cat.id}"))
    cat.add_relationship(Relationship.new('eu:domain',"#{facet}"))
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

SpinningCursor.stop

dir = "#{options[:path]}"
unless Dir.exists?(dir)
  Dir.mkdir(dir) or abort "Unable to create output directory #{dir}"
end

puts "Writing out to files..."
#write concept scheme
$concept_scheme.write_to_file(options[:path],options[:format][:name],options[:format][:extension],options[:format][:header],options[:format][:footer])
#and categories
$categories.each do |category|
  category.write_to_file(options[:path],options[:format][:name],options[:format][:extension],options[:format][:header],options[:format][:footer])
end
#now the rest of the resources
$resources.each do |resource|
  if options[:format][:name] == 'elastic'
    if resource.type == 'skos:Concept' || resource.type =~ /PlaceName/
      resource.write_to_file(options[:path],options[:format][:name],options[:format][:extension],options[:format][:header],options[:format][:footer])
    end
  else
    resource.write_to_file(options[:path],options[:format][:name],options[:format][:extension],options[:format][:header],options[:format][:footer])
  end
end