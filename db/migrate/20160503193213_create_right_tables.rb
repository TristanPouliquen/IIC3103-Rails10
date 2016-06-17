class CreateRightTables < ActiveRecord::Migration
  def change
    create_table :facturas do |t|
      t.string :idFactura
      t.timestamps null: false
    end

    create_table :orden_compras do |t|
      t.string :idOC
      t.timestamps null: false
    end
  end
end
