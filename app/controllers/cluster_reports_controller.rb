# frozen_string_literal: true

class ClusterReportsController < ApplicationController
  before_action :set_snapshot, only: %i[create]
  before_action :set_report, only: %i[show destroy deep_synthesis]

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
        redirect_to cluster_report_path(@report),
                    status: :see_other,
                    notice: "LLM Report analysis started in the background."
      end
      format.turbo_stream do
        redirect_to cluster_report_path(@report),
                    status: :see_other,
                    notice: "LLM Report analysis started in the background."
      end
    end
  end

  def destroy
    title = @report.title
    @report.destroy!

    redirect_to cluster_reports_path,
                status: :see_other,
                notice: "Report '#{title}' was successfully deleted."
  end

  def deep_synthesis
    if @report.detailed?
      redirect_to cluster_report_path(@report), alert: "A detailed report cannot generate another detailed report."
      return
    end

    batch_size = params[:batch_size].to_i
    batch_size = ClusterReport::DEFAULT_BATCH_SIZE if batch_size <= 0
    batch_size = batch_size.clamp(ClusterReport::BATCH_SIZE_RANGE)

    ClusterReport.transaction do
      @deep_report = @report.cluster_snapshot.cluster_reports.create!(
        prompt: @report.prompt,
        status: ClusterReport::STATUS_PENDING,
        is_detailed: true,
        batch_size: batch_size,
        parent_report: @report
      )
      @deep_report.copy_summaries_from!(@report)
    end

    GenerateClusterReportJob.perform_later(@deep_report.id)

    redirect_to cluster_report_path(@deep_report),
                notice: "Detailed synthesis started in the background."
  end

  private

  def set_snapshot
    @snapshot = ClusterSnapshot.find(params[:cluster_snapshot_id])
  end

  def set_report
    @report = ClusterReport.find(params[:id])
  end
end
