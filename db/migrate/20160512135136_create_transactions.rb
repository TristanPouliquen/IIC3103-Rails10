class CreateTransactions < ActiveRecord::Migration
  def change
    create_table :transactions do |t|
      t.string :idTrx
      t.string :origen
      t.string :destino
      t.integer :monto
      t.datetime :fecha

      t.timestamps null: false
    end
  end
end
