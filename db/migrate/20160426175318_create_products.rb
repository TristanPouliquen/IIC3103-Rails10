class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :sku
      t.float :costos
      t.references :warehouse, index: true, foreign_key: true


      t.timestamps null: false
    end
  end
end
