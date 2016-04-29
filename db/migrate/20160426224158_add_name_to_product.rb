class AddNameToProduct < ActiveRecord::Migration
  def change
    add_column :productos, :name, :string
  end
end
