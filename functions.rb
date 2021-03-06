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
      if $xl
        l = Property.new($id,c[key],language,'skosxl:Label')  
        if l.is_unique?
          if label_type =~ /prefLabel/
            l.inbound << resource.id
          end
          $id += 1
          $xl_labels << l
          r = Relationship.new(resource.id,label_type.gsub(/skos/,"skosxl"),l.id)
          resource.relationships << r
          $relationships << r
        else
          # get the xl_label that was already taken
          idx = $xl_labels.find_index {|x| x.text == l.text and x.language == l.language}
          target_id = $xl_labels[idx].id
          if label_type =~ /prefLabel/
            $xl_labels[idx].inbound << resource.id
          end
          r = Relationship.new(resource.id,label_type.gsub(/skos/,"skosxl"),target_id)
          resource.relationships << r
          $relationships << r
          #The following is still necessary for relationships mapping
          resource.labels << Property.new(nil, c[key],language,label_type)
        end
      else
        resource.labels << Property.new(nil, c[key],language,label_type)
      end
    end
  end
  
  ["AScope","CScope","EScope","FScope","RScope","SScope"].each do |key|
    if c[key] && c[key].size > 0
      language = $lang_hash["#{key[0]}"]
      resource.scope_notes << Property.new(nil,c[key],language, 'skos:scopeNote')
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
        r = Relationship.new($categories[coll_idx].id,'skos:member',resource.id)
        $categories[coll_idx].relationships << r
        $relationships << r
        m = Relationship.new(resource.id, 'eu:microThesaurus', $categories[coll_idx].id)
        resource.relationships << m
        $relationships << m
      end
      domain_idx = $categories.find_index {|r| r.id == facet.gsub(/\./,"")[0..1]}
      if domain_idx
        m = Relationship.new(resource.id, 'eu:domain', $categories[domain_idx].id)
        resource.relationships << m
        $relationships << m
      end
    end
  end
  r = Relationship.new(resource.id,'skos:inScheme','UNBISThesaurus')
  resource.relationships << r
  $relationships << r

  #history notes; these appear to be all in English
  if c["HistoryNote"] && c["HistoryNote"].size > 0
    resource.history_notes << Property.new(nil, c["HistoryNote"], "en", 'skos:historyNote')
  end

  #memo fields; these will go in skos:note entries
  ["AMemo","CMemo","EMemo","FMemo","RMemo","SMemo"].each do |key|
     if c[key] && c[key].size > 0
      language = $lang_hash["#{key[0]}"]
      resource.notes << Property.new(nil,c[key],language, 'skos:note')
    end
  end

  # set additional types based on whether term is geographic and/or placename
  if c["GeogTerm"] == 'Yes'
    r = Match.new(resource.id, "rdf:type", "unbist:GeographicTerm")
    resource.matches << r
    $relationships << r
  end
  if c["PlaceName"] == 'Yes'
    r = Match.new(resource.id, "rdf:type", "unbist:PlaceName")
    resource.matches << r
    $relationships << r
  end
  
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
          r = Relationship.new(resource.id,rel_type,target_id)
          resource.relationships << r
          $relationships << r
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
      if format_name == 'sql'
        $relationships.each do |relationship|
          file.puts(relationship.send("to_#{format_name}".to_sym))
        end
      end
      $xl_labels.uniq.each do |label|
        file.puts(label.send("to_#{format_name}".to_sym))
      end
      file.puts(footer)
    end
  end
end
