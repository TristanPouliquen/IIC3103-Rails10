class AddColumnIdOcToFactura < ActiveRecord::Migration
  def change
        add_column :facturas, :idOc, :string
  end
end
