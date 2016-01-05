class Resource
  attr_reader :id, :type, :labels, :scope_notes, :history_notes, :notes, :relationships, :properties, :rel_sql, :matches
  
  def initialize(id,type)
    @id = id
    @type = type
    @labels = Array.new
    @scope_notes = Array.new
    @history_notes = Array.new
    @notes = Array.new
    @relationships = Array.new
    @properties = Array.new
    @rel_sql = Array.new
    @matches = Array.new
  end
  
  def get_label_by(lang)
    label_idx = @labels.find_index {|l| l.language == lang}
    if label_idx
      return @labels[label_idx].text
    else
      return nil
    end
  end
  
  def get_id_by(label, lang = "en")
    if label == self.get_label_by(lang)
      return self
    else
      return nil
    end
  end
  
  def to_turtle
    id = @id
    turtle = ":#{id} rdf:type #{@type} ;\n"
    turtle_array = Array.new
    @labels.each do |l|
      turtle_array << "  #{l.type} #{l.text.to_json}@#{l.language}"
    end
    @properties.each do |p|
      turtle_array << "  #{p.type} #{p.text.to_json}@#{p.language}"
    end
    @scope_notes.each do |s|
      turtle_array << "  #{s.type} #{s.text.to_json}@#{s.language}"
    end
    @history_notes.each do |h|
      turtle_array << "  #{h.type} #{h.text.to_json}@#{h.language}"
    end
    @notes.each do |n|
      turtle_array << "  #{n.type} #{n.text.to_json}@#{n.language}"
    end
    @relationships.each do |r|
      turtle_array << "  #{r.type} :#{r.target}".gsub(/__/,"_")
    end
    @matches.each do |m|
      turtle_array << "  #{m.type} #{m.target}"
    end
    turtle += turtle_array.join(" ;\n") + " ."
    return turtle
  end
  
end
