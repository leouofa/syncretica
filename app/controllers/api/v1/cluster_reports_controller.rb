# frozen_string_literal: true

module Api
  module V1
    class ClusterReportsController < BaseController
      before_action :set_report, only: %i[show destroy deep_synthesis]

      def index
        scope = ClusterReport.includes(:cluster_snapshot).ordered
        scope = scope.where(cluster_snapshot_id: params[:cluster_snapshot_id]) if params[:cluster_snapshot_id].present?

        if params[:target_type].present?
          scope = scope.joins(:cluster_snapshot).where(cluster_snapshots: { target_type: params[:target_type].to_s.classify })
        end

        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(is_detailed: boolean_param(:is_detailed)) if params.key?(:is_detailed)

        records, meta = paginate(scope)
        data = records.map { |r| Serializer.cluster_report(r) }

        render_success(data, meta: meta)
      end

      def show
        render_success(
          Serializer.cluster_report(
            @report,
            include_summaries: boolean_param(:include_summaries, default: true),
            include_sub_reports: boolean_param(:include_sub_reports, default: true)
          )
        )
      end

      def create
        snapshot_id = params[:cluster_snapshot_id] || params.dig(:cluster_report, :cluster_snapshot_id)
        snapshot = ClusterSnapshot.find(snapshot_id)

        prompt = params[:prompt] || params.dig(:cluster_report, :prompt)
        prompt = prompt.to_s.squish.presence || ClusterReport::DEFAULT_PROMPT

        report = snapshot.cluster_reports.create!(
          prompt: prompt,
          status: ClusterReport::STATUS_PENDING
        )

        job = GenerateClusterReportJob.perform_later(report.id)
        render_success(
          Serializer.cluster_report(report),
          meta: { job_id: job.job_id },
          status: :created
        )
      end

      def destroy
        @report.destroy!
        render_success({ id: @report.id, title: @report.title, deleted: true })
      end

      def deep_synthesis
        if @report.detailed?
          return render_error(code: "already_detailed", message: "A detailed report cannot generate another detailed report.")
        end

        batch_size = (params[:batch_size] || params.dig(:cluster_report, :batch_size)).to_i
        batch_size = ClusterReport::DEFAULT_BATCH_SIZE if batch_size <= 0
        batch_size = batch_size.clamp(ClusterReport::BATCH_SIZE_RANGE)

        deep_report = nil
        ClusterReport.transaction do
          deep_report = @report.cluster_snapshot.cluster_reports.create!(
            prompt: @report.prompt,
            status: ClusterReport::STATUS_PENDING,
            is_detailed: true,
            batch_size: batch_size,
            parent_report: @report
          )
          deep_report.copy_summaries_from!(@report)
        end

        job = GenerateClusterReportJob.perform_later(deep_report.id)
        render_success(
          Serializer.cluster_report(deep_report),
          meta: { job_id: job.job_id },
          status: :created
        )
      end

      private

      def set_report
        @report = ClusterReport.find(params[:id])
      end
    end
  end
end
