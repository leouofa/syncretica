# frozen_string_literal: true

module Api
  module V1
    class ClustersController < BaseController
      def index
        target_class = resolve_target_class(params[:target_type])
        level = (params[:level] || 5).to_i.clamp(1, 15)
        full_coverage = boolean_param(:full_coverage, default: false) || level >= 15
        force = boolean_param(:force, default: false)

        result = Clustering::EmbeddingClusterer.call(
          target_class,
          level: level,
          full_coverage: full_coverage,
          force: force
        )
        unembedded_count = target_class.where(embedding: nil).count

        render_success(Serializer.live_cluster_result(result, unembedded_count: unembedded_count))
      end

      def snapshot
        target_class = resolve_target_class(params[:target_type])
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

      private

      def resolve_target_class(param)
        case param.to_s.downcase
        when "myth", "myths" then Myth
        else God
        end
      end
    end
  end
end
