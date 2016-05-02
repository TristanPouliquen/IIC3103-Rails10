class CreateOrdenCompras < ActiveRecord::Migration
  def change
    create_table :orden_compras do |t|
      t.integer :idOC

      t.timestamps null: false
    end
  end
end
