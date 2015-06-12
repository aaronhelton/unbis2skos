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
  raw_rbnts = Hash.new  
  
  resource = Resource.new(id,type)

  ["ATerm","CTerm","ETerm","FTerm","RTerm","STerm","AUF","CUF","EUF","FUF","RUF","SUF"].each do |key|
    if c[key] && c[key].size > 0
      language = $lang_hash["#{key[0]}"]
      label_type = 'skos:prefLabel'
      if key =~ /UF/
        label_type = 'skos:altLabel'
      end
      resource.labels << Property.new(c[key],language,label_type)
    end
  end
  
  ["AScope","CScope","EScope","FScope","RScope","SScope"].each do |key|
    if c[key] && c[key].size > 0
      language = $lang_hash["#{key[0]}"]
      resource.scope_notes << Property.new(c[key],language, 'skos:scopeNote')
    end
  end  
  
  ["BT","RT","NT"].each do |key|
    raw_rbnts["#{key}"] = parse_rel(c["#{key}"])
  end
  
  resource.properties << raw_rbnts
  
  if c["Facet"] && c["Facet"].size > 0
    c["Facet"].split(/\,/).each do |facet|
      coll_idx = $categories.find_index {|r| r.id == facet.gsub(/\./,"")}
      if coll_idx
        $categories[coll_idx].relationships << Relationship.new('skos:hasTopConcept',resource.id)
      end
    end
  end
  resource.relationships << Relationship.new('skos:inScheme','00')
  
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
        ridx = $resources.find_index {|r| r.get_id_by(relationship,'en') != nil}
        rel_type = $rel_hash["#{key}"]
        if ridx
          target_id = $resources[ridx].id.split(/\-/)[0]
          #puts "#{target_id}, #{rel_type}"
          resource.relationships << Relationship.new(rel_type,target_id)
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


def write_to_individual_files(path,format_name,extension,header,footer)
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
end

def write_one_big_file(path,format_name,outfile,extension,header,footer)
  puts "Writing to a single file..."
  unless Dir.exists?(path)
    Dir.mkdir(path) or abort "Unable to create #{path}\n"
  end
  unless File.exists?("#{path}/#{outfile}.#{extension}")
    File.open("#{path}/#{outfile}.#{extension}", "a+") do |file|
      file.puts(header)
      #file.puts(self.send("to_#{format}".to_sym))
      file.puts($concept_scheme.send("to_#{format_name}".to_sym))
      $categories.each do |category|
        file.puts(category.send("to_#{format_name}".to_sym))
      end
      $resources.each do |resource|
        file.puts(resource.send("to_#{format_name}".to_sym))
      end
      file.puts(footer)
    end
  end
end