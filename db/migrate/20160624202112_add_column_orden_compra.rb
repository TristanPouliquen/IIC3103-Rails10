class AddColumnOrdenCompra < ActiveRecord::Migration
  def change
  	add_column :orden_compras, :origen, :string
  	add_column :orden_compras, :destino, :string
  	add_column :orden_compras, :monto, :integer
  	add_column :orden_compras, :canal, :string
  	add_column :orden_compras, :cantidad, :integer
  	add_column :orden_compras, :cantidad_despachada, :integer
  	add_column :orden_compras, :estado, :string
  end
end
