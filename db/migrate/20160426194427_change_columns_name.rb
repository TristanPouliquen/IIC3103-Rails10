class ChangeColumnsName < ActiveRecord::Migration
  def change
  	drop_table :products
  	drop_table :warehouses
  end
end
