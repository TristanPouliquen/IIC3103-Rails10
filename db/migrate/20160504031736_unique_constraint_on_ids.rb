class UniqueConstraintOnIds < ActiveRecord::Migration
  def change
    add_index :facturas, [:idFactura], :unique => true
    add_index :orden_compras, [:idOC], :unique => true
  end
end
