# coding: utf-8
require 'sequel'

class Distributor < Sequel::Model(:distributors)
  many_to_many :products , left_key: :d_id, right_key: :p_id, join_table: :products_to_distributors
  many_to_many :materials , left_key: :d_id, right_key: :m_id, join_table: :materials_to_distributors
end

class ProductDistributor < Sequel::Model(:products_to_distributors)
end

class MaterialDistributor < Sequel::Model(:materialss_to_distributors)
end
