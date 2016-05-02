class CreateFacturas < ActiveRecord::Migration
  def change
    create_table :facturas do |t|
      t.integer :idFactura
      t.timestamps null: false
    end
  end
end
