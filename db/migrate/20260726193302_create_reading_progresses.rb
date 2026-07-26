class CreateReadingProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :reading_progresses do |t|
      t.references :volume, null: false, foreign_key: true, index: { unique: true }
      t.integer :current_page, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :last_read_at

      t.timestamps
    end
  end
end
