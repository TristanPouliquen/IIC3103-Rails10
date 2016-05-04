class CreateFtpFiles < ActiveRecord::Migration
  def change
    create_table :ftp_files do |t|
      t.string :name
      t.timestamps null: false
    end
  end
end
