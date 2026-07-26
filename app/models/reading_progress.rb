class ReadingProgress < ApplicationRecord
  belongs_to :volume

  enum :status, { unread: 0, in_progress: 1, completed: 2 }

  validates :volume_id, uniqueness: true
  validates :current_page, numericality: { greater_than_or_equal_to: 0 }

  def update_progress!(page:, total_pages:)
    update!(
      current_page: page,
      status: page >= total_pages - 1 ? :completed : (page.zero? ? :unread : :in_progress),
      last_read_at: Time.current
    )
  end
end
