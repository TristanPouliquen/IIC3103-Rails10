class AddColumnBoletaFactura < ActiveRecord::Migration
  def change
    add_column :boleta_facturas, :monto, :integer
    add_column :boleta_facturas, :estado, :string
  end
end
