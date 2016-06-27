class CreateSaldoDiarios < ActiveRecord::Migration
  def change
    create_table :saldo_diarios do |t|
      t.integer :saldo
      t.date :date

      t.timestamps null: false
    end
  end
end
