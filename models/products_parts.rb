# coding: utf-8
require 'sequel'

class ProductsPart < Sequel::Model
end

class PartsToAssemblies < Sequel::Model

  def get_parts
    PartsToAssemblies
      .select_group(:part_i_id, :part_p_id, :part__p_name___part_p_name, :assembly_i_id, :assembly_p_id, :assy__p_name___assembly_p_name, :assy__i_loc___assembly_i_loc, :assy__i_status___assembly_i_status)
      .join(:items___part, parts_to_assemblies__part_i_id: :part__i_id)
      .join(:items___assy, parts_to_assemblies__assembly_i_id: :assy__i_id)
      .where(assy__i_status: ["READY", "MUST_VERIFY"])
  end

  def get_parts_in_product p_id
    get_parts
      .where(assy__p_id: p_id)
  end

  def get_parts_in_product_with_location p_id, i_loc
    get_parts_in_product(p_id)
      .where(assy__i_loc: i_loc)
  end

  def get_parts_in_product_with_part_p_id p_id, part_p_id
    get_parts_in_product(p_id)
      .where(part_p_id: part_p_id)
  end

  def get_parts_with_part_p_id part_p_id
    get_parts
      .where(part_p_id: part_p_id)
  end

end
