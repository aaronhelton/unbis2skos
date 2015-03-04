class Label
  attr_reader :text, :language, :type

  def initialize(text,language, type)
    @text = text.upcase
    @language = language
    @type = type
  end

  def to_json(*a)
    {
      "text" => @text,
      "language" => @language,
      "type" => @type
    }.to_json(*a)
  end
end
