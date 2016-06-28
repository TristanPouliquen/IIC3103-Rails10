class StockDiario < ActiveRecord::Base
  store :stock, accessors: [:maiz, :carne, :tela_lana, :tequila, :suero_leche, :hamburguesa], coder: JSON
end
