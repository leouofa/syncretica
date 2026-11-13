# frozen_string_literal: true

module Api
  module V1
    class ClusterReportSummariesController < BaseController
      def index
        report = ClusterReport.find(params[:cluster_report_id])
        summaries = report.cluster_report_summaries.ordered.includes(:cluster_group)

        data = summaries.map { |s| Serializer.cluster_report_summary(s) }
        render_success(data, meta: { cluster_report_id: report.id, count: data.size })
      end

      def show
        summary = ClusterReportSummary.find(params[:id])
        render_success(Serializer.cluster_report_summary(summary))
      end
    end
  end
end
