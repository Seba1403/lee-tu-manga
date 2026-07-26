class Volume < ApplicationRecord
  belongs_to :series
  has_one :reading_progress, dependent: :destroy
  has_one_attached :cover

  validates :display_name, presence: true
  validates :file_path, presence: true, uniqueness: true
  validates :file_size, :file_mtime, :page_count, presence: true

  def progress
    reading_progress || build_reading_progress
  end

  def absolute_path
    File.join(LibraryScanner.root_path, file_path)
  end

  # position puede ser nil (nombre de archivo sin número reconocible), así que
  # el orden confiable es el de series.volumes, no una comparación numérica.
  def next_volume
    siblings = series.volumes.to_a
    siblings[siblings.index(self) + 1] if siblings.index(self)
  end

  def previous_volume
    siblings = series.volumes.to_a
    index = siblings.index(self)
    siblings[index - 1] if index && index > 0
  end
end
