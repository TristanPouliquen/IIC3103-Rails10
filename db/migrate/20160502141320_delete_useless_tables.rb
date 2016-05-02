class DeleteUselessTables < ActiveRecord::Migration
  def change
    drop_table :productos
    drop_table :almacens
  end
end
