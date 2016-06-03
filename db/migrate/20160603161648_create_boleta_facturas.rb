class CreateBoletaFacturas < ActiveRecord::Migration
  def change
    create_table :boleta_facturas do |t|
      t.string :factura
      t.string :boleta

      t.timestamps null: false
    end
  end
end
