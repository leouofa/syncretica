# frozen_string_literal: true

module Api
  module V1
    class PantheonsController < BaseController
      before_action :set_pantheon, only: %i[show update destroy populate_gods]

      def index
        scope = Pantheon.ordered
        scope = scope.where("name ILIKE :q OR description ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?

        gods_counts = God.group(:pantheon_id).count
        records, meta = paginate(scope)

        data = records.map do |pantheon|
          Serializer.pantheon(
            pantheon,
            include_gods: boolean_param(:include_gods, default: false),
            gods_count: gods_counts[pantheon.id] || 0
          )
        end

        render_success(data, meta: meta)
      end

      def show
        render_success(
          Serializer.pantheon(@pantheon, include_gods: boolean_param(:include_gods, default: true))
        )
      end

      def create
        pantheon = Pantheon.create!(pantheon_params)
        render_success(Serializer.pantheon(pantheon), status: :created)
      end

      def update
        @pantheon.update!(pantheon_params)
        render_success(Serializer.pantheon(@pantheon))
      end

      def destroy
        @pantheon.destroy!
        render_success({ id: @pantheon.id, name: @pantheon.name, deleted: true })
      end

      def upsert_batch
        entries = params.require(:pantheons).map do |entry|
          entry.permit(:name, :description).to_h
        end
        upserted = Pantheon.upsert_batch!(entries)
        render_success(
          upserted.map { |p| Serializer.pantheon(p) },
          meta: { count: upserted.size }
        )
      end

      def populate
        if sync_requested?
          result = PopulatePantheonsJob.perform_now
          render_success({ message: "Pantheons populated", result: result })
        else
          job = PopulatePantheonsJob.perform_later
          render_success({ job_id: job.job_id, status: "queued" }, status: :accepted)
        end
      end

      def populate_gods
        if sync_requested?
          upserted_count = PopulateGodsJob.new.populate_pantheon!(@pantheon)
          render_success({
            pantheon: { id: @pantheon.id, name: @pantheon.name },
            upserted_count: upserted_count
          })
        else
          job = PopulateGodsJob.perform_later(pantheon_id: @pantheon.id)
          render_success({ job_id: job.job_id, status: "queued", pantheon_id: @pantheon.id }, status: :accepted)
        end
      end

      private

      def set_pantheon
        @pantheon = Pantheon.find(params[:id])
      end

      def pantheon_params
        params.require(:pantheon).permit(:name, :description)
      end
    end
  end
end
