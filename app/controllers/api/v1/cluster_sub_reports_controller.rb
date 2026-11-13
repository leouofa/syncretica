# frozen_string_literal: true

module Api
  module V1
    class ClusterSubReportsController < BaseController
      def index
        report = ClusterReport.find(params[:cluster_report_id])
        sub_reports = report.cluster_sub_reports.ordered

        data = sub_reports.map { |sr| Serializer.cluster_sub_report(sr) }
        render_success(data, meta: { cluster_report_id: report.id, count: data.size })
      end

      def show
        sub_report = ClusterSubReport.find(params[:id])
        render_success(Serializer.cluster_sub_report(sub_report))
      end
    end
  end
end
