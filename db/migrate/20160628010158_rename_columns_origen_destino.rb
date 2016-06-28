class RenameColumnsOrigenDestino < ActiveRecord::Migration
  def change
    rename_column :orden_compras, :origen, :proveedor
    rename_column :orden_compras, :destino, :cliente
    rename_column :facturas, :origen, :proveedor
    rename_column :facturas, :destino, :cliente
  end
end
