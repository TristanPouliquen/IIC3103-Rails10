class DropTables < ActiveRecord::Migration
  def change
    drop_table :facturas
    drop_table :orden_compras
  end
end
