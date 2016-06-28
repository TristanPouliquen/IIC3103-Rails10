class CreateStockDiarios < ActiveRecord::Migration
  def change
    create_table :stock_diarios do |t|
      t.date :date
      t.text :stock

      t.timestamps null: false
    end
  end
end
