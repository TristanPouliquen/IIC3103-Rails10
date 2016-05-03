class ChangeIdToStrings < ActiveRecord::Migration
  def change
    change_column :facturas, :idFactura, :string
    change_column :orden_compras, :idOC, :string
  end
end
