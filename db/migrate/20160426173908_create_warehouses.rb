class CreateWarehouses < ActiveRecord::Migration
  def change
    create_table :warehouses do |t|
      t.integer :usedSpace
      t.integer :totalSpace
      t.boolean :reception
      t.boolean :dispatch
      t.boolean :backup

      t.timestamps null: false
    end
  end
end
