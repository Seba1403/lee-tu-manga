class CreateSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :series do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.string :folder_path, null: false

      t.timestamps
    end
    add_index :series, :slug, unique: true
    add_index :series, :folder_path, unique: true
  end
end
