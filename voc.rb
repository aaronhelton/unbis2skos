#!/usr/bin/ruby
# encoding: utf-8

require 'tmpdir'
require 'json'

# Variables that should probably come from argv
thesaurus = "thesaurus.sdf.utf8"
jsondir = "jsons"
thesaurusmap = "thesaurus-map.json"
skosfile = "thesaurus-skos.xml"

# Global class for Authority Records
class AuthorityRecord
  def initialize()
    @data = Hash.new { |hash, key| hash[key] = [] }
  end
  def [](key)
    @data[key]
  end
  def []=(key,words)
    @data[key] += [words].flatten
    @data[key].uniq!
  end
end

def jsonify(infile,outdir)
  debug = 1
  # Transforms single SDF file to a collection of JSON formatted files representing each term.
  # Check if infile exists and is readable.  Exit otherwise.
  unless File.exists?(infile) && File.readable?(infile)
    abort "File #{infile} does not exist or is not readable."
  end
  # Check if outdir exists, create it if necessary
  if !Dir.exists?(outdir) 
    Dir.mkdir(outdir) or abort "Unable to create the directory #{outdir}.  Perhaps you don't have permission."
  end
  # One more thing, can we make a tmpdir?
  tmpdir = Dir.mktmpdir or abort "Could not make a temporary directory."
  if debug == 1
    puts tmpdir
  end
  # we should be good now, let's proceed
  # First we make temporary SDFs, which we can discard later
  i = 0
  File.foreach(infile) do |line|
    if line !~ /:/ 
      if debug == 1
        puts "Adding to file sdf-" + i.to_s + ".sdf"
      end
      i = i + 1
    else
      outfile = "#{tmpdir}/sdf-" + i.to_s + ".sdf"
      File.open(outfile, "a") do |out|
        out.puts line
      end
    end
  end
  # Next we jsonify these files and write them to the outdir
  Dir.foreach(tmpdir) do |file|
    if file != "." && file != ".."
      fh = File.open("#{tmpdir}/#{file}", "rb")
      authrecord = fh.read
      fh.close
      recordid = ""
      record_hash = Hash.new
      authrecord.split("\n").each do |line|
        if line =~ /Recordid/
          recordid = line.split(": ")[1].gsub(/\s+/,"")
        end
        key = line.split(": ")[0].strip
        value = line.split(": ")[1].encode('UTF-8','UTF-8').strip
        record_hash.merge!(key => value)
      end
      File.open("#{outdir}/#{recordid}.json", "a") do |out|
        out.puts record_hash.to_json
      end
    end
  end
end

def makemap(indir,mapfile)
  # Makes JSON formatted map file(s) to lookup by T code and by ETerm
end

def skosify(indir,mapfile,outfile)
  # outputs SKOS Core formatted XML
end

jsonify(thesaurus,jsondir)


