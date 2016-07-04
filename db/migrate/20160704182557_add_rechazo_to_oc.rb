class AddRechazoToOc < ActiveRecord::Migration
  def change
    add_column :orden_compras, :rechazo, :text
  end
end
