# frozen_string_literal: true

module Api
  module V1
    class ClusterGroupsController < BaseController
      def index
        snapshot = ClusterSnapshot.find(params[:cluster_snapshot_id])
        groups = snapshot.cluster_groups.by_size
        include_members = boolean_param(:include_members, default: true)

        data = groups.map do |group|
          Serializer.cluster_group(group, include_members: include_members)
        end

        render_success(data, meta: { cluster_snapshot_id: snapshot.id, count: data.size })
      end

      def show
        group = ClusterGroup.find(params[:id])
        render_success(
          Serializer.cluster_group(group, include_members: boolean_param(:include_members, default: true))
        )
      end
    end
  end
end
