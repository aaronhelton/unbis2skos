#!/usr/bin/ruby
# encoding: utf-8

require 'tmpdir'
require 'json'
require 'net/http'

# Variables that should probably come from argv
thesaurus = "thesaurus.sdf.utf8"
jsondir = "jsons"
thesaurusmap = "thesaurus-map.json"
skosfile = "thesaurus-skos.xml"

def makemap(indir,mapfile)
  termmap = Hash.new
  map = Hash.new
  listpaths = Array.new
  listbasepath = "/LIB/DHLUNBISThesaurus.nsf/BrowseEng?OpenView&Start="
  host = "lib-thesaurus.un.org"
  i = 1
  while i < 8000 do
    listpaths << "#{listbasepath}#{i}&Count=1000"
    i = i + 1000
  end
  listpaths.each do |path|
    tempdoc = Net::HTTP.get(host,path).split("\n")
    tempdoc.each do |line|
      if line =~ /fee3fb01c865ac5d85256cf400648b1f/
        if line =~ /2367c500d9f2df7785256d1f00595de9/
          # Special exception for LA NIÑA CURRENT
          term = "LA NINA CURRENT"
        elsif line =~ /9e4ae9cd23a675a885256aa000601af9/
          # Special exception for EL NIÑO CURRENT
          term = "EL NINO CURRENT"
        else
          term = line.split('<a href="')[1].split('">')[1].split("</a>")[0]
        end
        termpath = line.split('<a href="')[1].split('"')[0].gsub(/\?OpenDocument/, "")
        uri = "http://#{host}#{termpath}"
        puts term.encode('UTF-8','UTF-8')
        termmap.merge!(term.encode('UTF-8','UTF-8') => uri)
      end
    end
  end 
  Dir.foreach(indir) do |file|
    if file != "." && file != ".."
      rec = File.read("#{indir}/#{file}")
      jrec = JSON.parse(rec)
      recordid = jrec['Recordid']
      if recordid == 'T0013483'
        # Special exception for LA NIÑA CURRENT
        eterm = "LA NINA CURRENT"
      elsif recordid == 'T0010244'
        # Special exception for EL NIÑO CURRENT
        eterm = "EL NINO CURRENT"
      else
        eterm = jrec['ETerm'].encode('UTF-8','UTF-8')
      end
      id = file.split(".")[0]
      # We are going to create two views, one for a lookup by eterm, and the other for lookup by T* identifier
      # This might not be necessary, but it is logical to me.  Anyway it will allow lookups like map[term] and map[id]
      map.merge!(eterm => { "id" => id, "uri" => termmap[eterm], "term" => jrec['ETerm'] } )
      map.merge!(id => { "id" => id, "uri" => termmap[eterm], "term" => jrec['ETerm'] } )
    end
  end
  File.open(mapfile, "w+") do |out|
    out.puts map.to_json
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

def skosify(indir,mapfile,outfile)
  # outputs SKOS Core formatted XML
  map = JSON.parse(File.read("#{mapfile}")) or abort "Could not open map file #{mapfile}."
  File.open(outfile, "w+") do |out|
    out.puts '<?xml version="1.0" encoding="UTF-8"?>'
    out.puts '<rdf:RDF'
    out.puts '  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"'
    out.puts '  xmlns:owl="http://www.w3.org/2002/07/owl#"'
    out.puts '  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"'
    out.puts '  xmlns:skos="http://www.w3.org/2004/02/skos/core#"'
    out.puts '  xmlns:dc="http://purl.org/dc/elements/1.1/"'
    out.puts '  xmlns:xsd="http://www.w3.org/2001/XMLSchema#">'
    out.puts '  <skos:ConceptScheme rdf:about="http://lib-thesaurus.un.org">'
    out.puts '    <skos:prefLabel>UNBIS Thesaurus</skos:prefLabel>'
    out.puts '  </skos:ConceptScheme>'
    Dir.foreach(indir) do |file|
      unless file == "." || file == ".."
        rec = JSON.parse(File.read("#{indir}/#{file}"))
        recordid = rec['Recordid']
        if recordid == 'T0013483'
          # Special exception for LA NIÑA CURRENT
          eterm = "LA NINA CURRENT"
        elsif recordid == 'T0010244'
          # Special exception for EL NIÑO CURRENT
          eterm = "EL NINO CURRENT"
        else
          eterm = rec['ETerm']
        end
        out.puts '  <skos:Concept rdf:about="' + map[recordid]["uri"] + '">'
        out.puts '    <skos:externalID>' + recordid + '</skos:externalID>'
        if rec['ATerm'] then out.puts '    <skos:prefLabel xml:lang="ar">' + rec['ATerm'] + '</skos:prefLabel>' end
        if rec['CTerm'] then out.puts '    <skos:prefLabel xml:lang="zh">' + rec['CTerm'] + '</skos:prefLabel>' end
        if rec['ETerm'] then out.puts '    <skos:prefLabel xml:lang="en">' + rec['ETerm'] + '</skos:prefLabel>' end
        if rec['FTerm'] then out.puts '    <skos:prefLabel xml:lang="fr">' + rec['FTerm'] + '</skos:prefLabel>' end
        if rec['RTerm'] then out.puts '    <skos:prefLabel xml:lang="ru">' + rec['RTerm'] + '</skos:prefLabel>' end
        if rec['STerm'] then out.puts '    <skos:prefLabel xml:lang="es">' + rec['STerm'] + '</skos:prefLabel>' end
        if rec['BT'] != ""
          bt_one = rec['BT'].gsub(/,/,";").gsub(/; /,", ")
          if bt_one =~ /;/
            bt_one.split(";").each do |bt|
              out.puts '    <skos:broader rdf:resource="' + map[bt]["uri"] + '"/>'
            end
          else
            out.puts '    <skos:broader rdf:resource="' + map[bt_one]["uri"] + '"/>'
          end
        end
        if rec['NT'] != ""
          nt_one = rec['NT'].gsub(/,/,";").gsub(/; /,", ")
          if nt_one =~ /;/
            nt_one.split(";").each do |nt|
              if nt =~ /O CURRENT/
                out.puts '    <skos:narrower rdf:resource="' + map["EL NINO CURRENT"]["uri"]  + '"/>'
              elsif nt =~ /A CURRENT/
                out.puts '    <skos:narrower rdf:resource="' + map["LA NINA CURRENT"]["uri"]  + '"/>'
              else
                out.puts '    <skos:narrower rdf:resource="' + map[nt]["uri"] + '"/>'
              end
            end
          else
            out.puts '    <skos:narrower rdf:resource="' + map[nt_one]["uri"] + '"/>'
          end
        end
        if rec['RT'] != ""
          rt_one = rec['RT'].gsub(/,/,";").gsub(/; /,", ")
          puts rt_one
          if rt_one =~ /;/
            rt_one.split(";").each do |rt|
              if rt =~ /O CURRENT/
                out.puts '    <skos:related rdf:resource="' + map["EL NINO CURRENT"]["uri"]  + '"/>'
              elsif rt =~ /A CURRENT/
                out.puts '    <skos:related rdf:resource="' + map["LA NINA CURRENT"]["uri"]  + '"/>'
              else
                if map[rt] then out.puts '    <skos:related rdf:resource="' + map[rt]["uri"] + '"/>' end
              end
            end
          else
            if map[rt_one] then out.puts '    <skos:narrower rdf:resource="' + map[rt_one]["uri"] + '"/>' end
          end
        end
        out.puts '    <skos:inScheme rdf:resource="http://lib-thesaurus.un.org"/>'
        out.puts '  </skos:Concept>'
      end
    end
    out.puts '</rdf:RDF>'
  end
end

#These need to be ARGV-ified at some point
#For now, just uncomment the ones you need.

#jsonify(thesaurus,jsondir)
#makemap(jsondir,thesaurusmap)
skosify(jsondir,thesaurusmap,skosfile)
