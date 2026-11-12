# frozen_string_literal: true

class ClusterMembership < ApplicationRecord
  belongs_to :cluster_group, counter_cache: :size
  belongs_to :record, polymorphic: true

  validates :record_id, uniqueness: { scope: %i[cluster_group_id record_type] }
end
