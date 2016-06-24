class AddColumnFactura < ActiveRecord::Migration
  def change
  	add_column :facturas, :origen, :string
  	add_column :facturas, :destino, :string
  	add_column :facturas, :monto, :integer
  	add_column :facturas, :estado, :string
  end
end
