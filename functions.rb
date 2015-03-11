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
  labels = [    Label.new(c["ATerm"],"ar","preferred"),
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
    mt_idx = $microthesauri.find_index {|mt| mt.id == s}
    if mt_idx
      #puts "Adding #{uri} to top_concepts of #{$microthesauri[mt_idx].id}"
      $microthesauri[mt_idx].add_top_concept(uri)
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

  concept = Concept.new(id, uri, nil, nil, labels, in_scheme, scope_notes, raw_rbnts)
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

def make_domains_and_microthesauri(catdir)
  id = nil
  domains = Array.new
  microthesauri = Array.new
  Dir.foreach(catdir) do |file|
    unless file == "." || file == ".."
      id = file.gsub(/\./,"").to_s
      if id == "00" then next end
      uri = "#{$base_uri}#{id}"
      labels = Array.new
      File.read("#{catdir}/#{file}").split(/\n/).each do |line|
        label = JSON.parse(line)
        labels << Label.new(label["text"],label["language"],"preferred")
      end
      if id.size > 2
        mt_idx = microthesauri.find_index {|m| m.id == id}
        #we know the domain from the id
        d_uri = "#{$base_uri}#{id[0..1]}"
        if mt_idx
          #mt exists, so we just update it
          microthesauri[mt_idx].labels = labels
          microthesauri[mt_idx].uri = uri
          microthesauri[mt_idx].domain = d_uri
        else
          #mt doesn't exist, so we create it
          m = Microthesaurus.new(id, uri, labels, d_uri)
          #puts m.inspect
          microthesauri << m
        end
      else
        d_idx = domains.find_index {|d| d.id == id}
        #but we don't know the microthesauri
        if d_idx
          #d exists, so update it
          domains[d_idx].labels = labels
          domains[d_idx].uri = uri
        else
          #d does not exist, so create it
          d = Domain.new(id, uri, labels, $base_uri + "00")
          #puts d.inspect
          domains << d
        end
      end
    end
  end
  microthesauri.each do |m|
    #each must have a domain; now add the mt to its domain
    if m.domain
      id = m.domain.split(/\=/).last
      domain_idx = domains.find_index {|d| d.id == id}
      if domain_idx
        domains[domain_idx].add_microthesaurus(m.uri)
      end
    end
    #now map the backward relationship from concept to microthesaurus
    if m.top_concepts.size > 0
      m.top_concepts.each do |tc|
        cid = tc.split(/\=/).last
        idx = $concepts.find_index {|c| c.id == cid}
        if idx
          $concepts[idx].add_microthesaurus(m.uri)
        end
      end
    end
  end
  return [domains,microthesauri]
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

