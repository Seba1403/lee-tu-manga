class Series < ApplicationRecord
  # Tomos sin número reconocible en el nombre de archivo (position: nil)
  # quedan al final, ordenados por nombre.
  has_many :volumes, -> { order(Arel.sql("position IS NULL"), :position, :display_name) }, dependent: :destroy

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :folder_path, presence: true, uniqueness: true

  def to_param
    slug
  end

  def cover
    volumes.first&.cover
  end
end
