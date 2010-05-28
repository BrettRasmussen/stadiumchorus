class CreateSingers < ActiveRecord::Migration
  def self.up
    create_table :singers do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.date :birthdate
      t.string :phone
      t.string :voicepart
      t.string :status
      t.text :comments
      t.timestamps
    end
  end

  def self.down
    drop_table :singers
  end
end
