# frozen_string_literal: true

module Api
  module V1
    class ClusterSnapshotsController < BaseController
      before_action :set_snapshot, only: %i[show destroy]

      def index
        scope = ClusterSnapshot.ordered
        if params[:target_type].present?
          scope = scope.for_target(params[:target_type].to_s.classify)
        end

        records, meta = paginate(scope)
        include_groups = boolean_param(:include_groups, default: false)

        data = records.map do |snapshot|
          Serializer.cluster_snapshot(snapshot, include_groups: include_groups)
        end

        render_success(data, meta: meta)
      end

      def show
        render_success(
          Serializer.cluster_snapshot(
            @snapshot,
            include_groups: boolean_param(:include_groups, default: true),
            include_members: boolean_param(:include_members, default: true),
            include_reports: boolean_param(:include_reports, default: true)
          )
        )
      end

      def create
        target_class = params[:target_type].to_s.downcase == "myth" ? Myth : God
        level = (params[:level] || 5).to_i.clamp(1, 15)
        full_coverage = boolean_param(:full_coverage, default: false) || level >= 15

        result = Clustering::EmbeddingClusterer.call(
          target_class,
          level: level,
          full_coverage: full_coverage,
          force: true
        )
        snapshot = result.snapshot!(title: params[:title])

        render_success(
          Serializer.cluster_snapshot(snapshot, include_groups: true, include_members: true),
          status: :created
        )
      end

      def destroy
        @snapshot.destroy!
        render_success({ id: @snapshot.id, title: @snapshot.title, deleted: true })
      end

      private

      def set_snapshot
        @snapshot = ClusterSnapshot.find(params[:id])
      end
    end
  end
end
