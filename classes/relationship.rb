class Relationship
  attr_reader :source, :type,:target
  
  def initialize(source,type,target)
    @source = source
    @type = type
    @target = target
  end
  
  def to_sql
    sql = nil
    sql = "insert into thesaurus_relationship (relationship_source_id, relationship_type, relationship_target_id) values((select id from thesaurus_resource where uri = '#{@source}'), '#{@type}', (select id from thesaurus_resource where uri = '#{@target}'));"
    return sql
  end
end