# frozen_string_literal: true

class ClusterSnapshotsController < ApplicationController
  before_action :set_snapshot, only: %i[show destroy]

  def index
    @snapshots = ClusterSnapshot.ordered.includes(:cluster_reports)
    @target_type = params[:target_type].presence
    @snapshots = @snapshots.for_target(@target_type) if @target_type.present?
  end

  def show
    @cluster_groups = @snapshot.cluster_groups.by_size.includes(cluster_memberships: :record)
    @reports = @snapshot.cluster_reports.ordered
    @new_report = @snapshot.cluster_reports.build
  end

  def destroy
    target = @snapshot.target_type.downcase.pluralize
    title = @snapshot.title
    @snapshot.destroy!

    redirect_to cluster_snapshots_path, notice: "Snapshot '#{title}' was successfully removed."
  end

  private

  def set_snapshot
    @snapshot = ClusterSnapshot.find(params[:id])
  end
end
