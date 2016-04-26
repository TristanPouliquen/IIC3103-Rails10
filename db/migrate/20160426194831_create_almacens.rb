class CreateAlmacens < ActiveRecord::Migration
  def change
    create_table :almacens do |t|
      t.integer :espacioUtilizado
      t.integer :espacioTotal
      t.boolean :recepcion
      t.boolean :despacho
      t.boolean :pulmon

      t.timestamps null: false
    end
  end
end
