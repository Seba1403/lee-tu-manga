class CreateVolumes < ActiveRecord::Migration[8.1]
  def change
    create_table :volumes do |t|
      t.references :series, null: false, foreign_key: true
      t.decimal :position, precision: 6, scale: 1
      t.string :display_name, null: false
      t.string :file_path, null: false
      t.integer :file_size, null: false
      t.datetime :file_mtime, null: false
      t.integer :page_count, null: false
      t.integer :cover_page_index, null: false, default: 0

      t.timestamps
    end
    add_index :volumes, :file_path, unique: true
    add_index :volumes, [ :series_id, :position ]
  end
end
