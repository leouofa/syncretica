# frozen_string_literal: true

class ClusterReportsController < ApplicationController
  before_action :set_snapshot, only: %i[create]
  before_action :set_report, only: %i[show destroy]

  def index
    @reports = ClusterReport.includes(:cluster_snapshot).ordered
    @target_type = params[:target_type].presence
    if @target_type.present?
      @reports = @reports.joins(:cluster_snapshot).where(cluster_snapshots: { target_type: @target_type })
    end
  end

  def show
  end

  def create
    prompt = params.dig(:cluster_report, :prompt).to_s.squish
    prompt = ClusterReport::DEFAULT_PROMPT if prompt.blank?

    @report = @snapshot.cluster_reports.create!(
      prompt: prompt,
      status: ClusterReport::STATUS_PENDING
    )

    GenerateClusterReportJob.perform_later(@report.id)

    respond_to do |format|
      format.html do
        redirect_to cluster_snapshot_path(@snapshot),
                    notice: "LLM Report analysis started in the background."
      end
      format.turbo_stream
    end
  end

  def destroy
    snapshot = @report.cluster_snapshot
    title = @report.title
    @report.destroy!

    respond_to do |format|
      format.html do
        redirect_back fallback_location: cluster_snapshot_path(snapshot),
                      notice: "Report '#{title}' was successfully deleted."
      end
      format.turbo_stream { render turbo_stream: turbo_stream.remove("cluster_report_#{@report.id}") }
    end
  end

  private

  def set_snapshot
    @snapshot = ClusterSnapshot.find(params[:cluster_snapshot_id])
  end

  def set_report
    @report = ClusterReport.find(params[:id])
  end
end
