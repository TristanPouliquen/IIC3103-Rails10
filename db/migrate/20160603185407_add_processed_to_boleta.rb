class AddProcessedToBoleta < ActiveRecord::Migration
  def change
    add_column :boleta_facturas, :processed, :boolean
  end
end
