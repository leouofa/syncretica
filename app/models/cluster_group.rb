# frozen_string_literal: true

class ClusterGroup < ApplicationRecord
  belongs_to :cluster_snapshot
  has_many :cluster_memberships, dependent: :destroy

  validates :name, presence: true

  scope :by_size, -> { order(size: :desc, id: :asc) }
end
