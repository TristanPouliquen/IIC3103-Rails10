class CreateProductos < ActiveRecord::Migration
  def change
    create_table :productos do |t|
      t.integer :sku
      t.float :costos
      t.references :almacen, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
