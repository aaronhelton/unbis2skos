##############################
## Global Functions
##############################

$lang_hash = { 'A' => 'ar', 'C' => 'zh', 'E' => 'en', 'F' => 'fr', 'R' => 'ru', 'S' => 'es' }
$rel_hash = {'BT' => 'skos:broader', 'RT' => 'skos:related', 'NT' => 'skos:narrower'}

def readfile(infile,tmpdir)
  unless File.exists?(infile) && File.readable?(infile)
    abort "Input file#{infile} does not exist or is not readable."
  end
  
  i = 0
  File.foreach(infile) do |line|
    if line !~ /:/
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
      File.read("#{tmpdir}/#{file}").split(/\n/).each do |line|
        if line =~ /Recordid\:/
          recordid = line.split(": ")[1].gsub(/\s+/,"")
        end
        key = line.split(": ")[0].strip
        value = line.split(": ")[1].encode('UTF-8','UTF-8').strip
        sdf_record_hash.merge!(key => value)
      end
      parse_raw(sdf_record_hash)
    end
  end
end

def parse_raw(c)
  id = c["Recordid"]
  type = 'skos:Concept'
  routable = false
  raw_rbnts = Hash.new
  if c["GeogTerm"] =~ /Yes/
    type = 'unbist:PlaceName'
    routable = true #??
  end
  
  
  resource = Resource.new(id,type,nil,routable,nil)
  
  ["ATerm","CTerm","ETerm","FTerm","RTerm","STerm","AUF","CUF","EUF","FUF","RUF","SUF"].each do |key|
    if c[key] && c[key].size > 0
      language = $lang_hash["#{key[0]}"]
      label_type = 'skosxl:prefLabel'
      if key =~ /UF/
        label_type = 'skosxl:altLabel'
      end
      label = Resource.new("#{id}-#{label_type.gsub(/skosxl\:/,'')}-#{language}","skosxl:Label",c[key],false,language)
      $resources << label      
      resource.add_relationship(Relationship.new(label_type,"#{id}-#{label_type.gsub(/skosxl\:/,'')}-#{language}"))
    end
  end
  
  ["AScope","CScope","EScope","FScope","RScope","SScope"].each do |key|
    if c[key] && c[key].size > 0
      language = $lang_hash["#{key[0]}"]
      note = Resource.new("#{id}-scopenote-#{language}","skos:scopeNote",c[key],false,language)
      $resources << note
      resource.add_relationship(Relationship.new('skos:scopeNote',"#{id}-scopenote-#{language}"))
    end
  end  
  
  ["BT","RT","NT"].each do |key|
    raw_rbnts["#{key}"] = parse_rel(c["#{key}"])
  end
  
  resource.add_property(raw_rbnts)
  
  if c["Facet"] && c["Facet"].size > 0
    c["Facet"].split(/\,/).each do |facet|
      #puts facet
      resource.add_relationship(Relationship.new('eu:microThesaurus',facet))
      domain = facet.split(/\./).first
      resource.add_relationship(Relationship.new('eu:domain',domain))
      #didx = $resources.find_index {|r| r.id == domain}
      midx = $categories.find_index {|r| r.id == facet}
      if midx
        $categories[midx].add_relationship(Relationship.new('skos:hasTopConcept',resource.id))
      end
    end
  end
  resource.add_relationship(Relationship.new('skos:inScheme','00'))
  
  $resources << resource
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

def map_raw_to_rel(resource)
  raw = resource.properties.first
  ["BT","RT","NT"].each do |key|
    raw["#{key}"].each do |relationship|
      if relationship && relationship.size > 0
        ridx = $resources.find_index {|r| r.literal == relationship}
        rel_type = $rel_hash["#{key}"]
        if ridx
          target_id = $resources[ridx].id.split(/\-/)[0]
          #puts "#{target_id}, #{rel_type}"
          resource.add_relationship(Relationship.new(rel_type,target_id))
        end
      end
    end
  end
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