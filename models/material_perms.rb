class Material < Sequel::Model(:materials)

  def self.can_list?(actor)
    true
  end

  def can_view?(actor)
    actor.is_a?(User)
  end

  def can_update?(actor)
    actor.is_a?(User) && (actor.level >= 3 || self.owned_by?(actor))
  end

end
