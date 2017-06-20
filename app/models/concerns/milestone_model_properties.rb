module MilestoneModelProperties
  extend ActiveSupport::Concern

  include StripAttribute
  include CacheMarkdownField

  included do
    has_many :issues
    has_many :merge_requests
    has_many :labels, -> { distinct.reorder('labels.title') },  through: :issues

    # Use a uniqueness scope here to check name with project milestones
    validates :title, presence: true#, uniqueness: { scope: :project_id }

    scope :active, -> { with_state(:active) }
    scope :closed, -> { with_state(:closed) }

    validate :start_date_should_be_less_than_due_date, if: proc { |m| m.start_date.present? && m.due_date.present? }
    strip_attributes :title
    alias_attribute :name, :title

    state_machine :state, initial: :active do
      event :close do
        transition active: :closed
      end

      event :activate do
        transition closed: :active
      end

      state :closed

      state :active
    end

    alias_attribute :name, :title

    cache_markdown_field :title, pipeline: :single_line
    cache_markdown_field :description
  end

  def start_date_should_be_less_than_due_date
    if due_date <= start_date
      errors.add(:start_date, "Can't be greater than due date")
    end
  end

  def safe_title
    title.to_slug.normalize.to_s
  end
end
