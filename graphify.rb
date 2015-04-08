#!/bin/env ruby
# encoding: utf-8

require 'optparse'
require 'pp'
require 'tmpdir'
require 'json'
require 'spinning_cursor'
require_relative 'classes/resource.rb'
require_relative 'classes/relationship.rb'
require_relative 'functions.rb'

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

end.parse!

if !options[:infile] then abort "Missing input file argument." end
if !options[:catdir] then abort "Missing categories directory argument." end

$resources = Array.new

# Create ConceptScheme first
$concept_scheme = Resource.new()

# Process categories next


# Now process concepts
