class ScopeNote
  attr_reader :text, :language

  def initialize(text,language)
    @text = text
    @language = language
  end

  def to_json(*a)
    {
      "text" => @text,
      "language" => @language
    }.to_json(*a)
  end
end
