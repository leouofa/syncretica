# frozen_string_literal: true

class ClustersController < ApplicationController
  before_action :set_target_and_level

  def index
    @result = Clustering::EmbeddingClusterer.call(@target_class, level: @level)
    @unembedded_count = @target_class.where(embedding: nil).count
    @snapshots = ClusterSnapshot.for_target(@target_class.name).ordered.limit(10)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def snapshot
    result = Clustering::EmbeddingClusterer.call(@target_class, level: @level)
    snapshot = result.snapshot!(title: params[:title])

    redirect_to cluster_snapshot_path(snapshot),
                notice: "Cluster snapshot '#{snapshot.title}' saved successfully with #{snapshot.clusters_count} clusters."
  rescue StandardError => e
    redirect_to clusters_path(tab: @tab, level: @level),
                alert: "Failed to save snapshot: #{e.message}"
  end

  private

  def set_target_and_level
    @tab = params[:tab].to_s.downcase == "myths" ? "myths" : "gods"
    @target_class = @tab == "myths" ? Myth : God
    @level = (params[:level] || 5).to_i.clamp(1, 10)
  end
end
