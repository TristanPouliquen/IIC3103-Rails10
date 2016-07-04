class AddSkuToOc < ActiveRecord::Migration
  def change
    add_column :orden_compras, :sku, :string
  end
end
