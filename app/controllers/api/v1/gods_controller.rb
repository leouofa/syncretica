# frozen_string_literal: true

module Api
  module V1
    class GodsController < BaseController
      before_action :set_god, only: %i[show update destroy neighbors generate_embedding populate_myth]

      def index
        scope = God.includes(:pantheon)
        scope = scope.where(pantheon_id: params[:pantheon_id]) if params[:pantheon_id].present?
        if params[:pantheon].present?
          scope = scope.joins(:pantheon).where("pantheons.name ILIKE ?", "%#{params[:pantheon]}%")
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements_text(gods.themes) elem WHERE elem ILIKE ?)", "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.where("gods.name ILIKE :q OR gods.description ILIKE :q", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("gods.name ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        include_myth = boolean_param(:include_myth, default: false)

        data = records.map do |god|
          Serializer.god(god, include_embedding: include_embedding, include_myth: include_myth)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = God.includes(:pantheon)
        scope = scope.where(pantheon_id: params[:pantheon_id]) if params[:pantheon_id].present?

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |god|
              dist = god.try(:neighbor_distance)
              Serializer.god(god, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
            # In auto mode, fallback to keyword search if embedding generation fails
          end
        end

        # Keyword search fallback
        keyword_matches = scope.where("gods.name ILIKE :q OR gods.description ILIKE :q", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |god| Serializer.god(god) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.god(
            @god,
            include_embedding: boolean_param(:include_embedding, default: false),
            include_myth: boolean_param(:include_myth, default: true)
          )
        )
      end

      def create
        god = God.create!(god_params)
        render_success(Serializer.god(god), status: :created)
      end

      def update
        @god.update!(god_params)
        render_success(Serializer.god(@god))
      end

      def destroy
        @god.destroy!
        render_success({ id: @god.id, name: @god.name, deleted: true })
      end

      def neighbors
        unless @god.embedded?
          return render_error(code: "not_embedded", message: "God '#{@god.name}' does not have an embedding yet")
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 100)
        scope = God.includes(:pantheon).where.not(id: @god.id)
        scope = scope.where(pantheon_id: params[:pantheon_id]) if params[:pantheon_id].present?

        neighbors = scope.nearest_neighbors(:embedding, @god.embedding, distance: "cosine").limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.god(neighbor, neighbor_distance: neighbor.try(:neighbor_distance))
        end

        render_success(results, meta: { god_id: @god.id, count: results.size })
      end

      def generate_embedding
        if sync_requested?
          @god.generate_embedding!
          render_success(Serializer.god(@god, include_embedding: boolean_param(:include_embedding, default: false)))
        else
          job = GenerateEmbeddingJob.perform_later("God", @god.id)
          render_success({ job_id: job.job_id, status: "queued", god_id: @god.id }, status: :accepted)
        end
      end

      def populate_myth
        if sync_requested?
          myth = PopulateMythsJob.new.populate_god!(@god)
          render_success(Serializer.myth(myth))
        else
          job = PopulateMythsJob.perform_later(god_id: @god.id)
          render_success({ job_id: job.job_id, status: "queued", god_id: @god.id }, status: :accepted)
        end
      end

      def populate
        pantheon_id = params[:pantheon_id].presence
        if sync_requested?
          result = PopulateGodsJob.new.perform(pantheon_id: pantheon_id)
          render_success({ message: "Gods populated", result: result })
        else
          job = PopulateGodsJob.perform_later(pantheon_id: pantheon_id)
          render_success({ job_id: job.job_id, status: "queued", pantheon_id: pantheon_id }, status: :accepted)
        end
      end

      def upsert_batch
        pantheon = Pantheon.find(params.require(:pantheon_id))
        entries = params.require(:gods).map do |entry|
          entry.permit(:name, :description, themes: []).to_h
        end
        upserted = God.upsert_batch!(pantheon, entries)
        render_success(
          upserted.map { |g| Serializer.god(g) },
          meta: { pantheon_id: pantheon.id, count: upserted.size }
        )
      end

      private

      def set_god
        @god = God.includes(:pantheon, :myth).find(params[:id])
      end

      def god_params
        p = params.require(:god).permit(:pantheon_id, :name, :description, themes: [])
        p[:themes] = God.normalize_themes(p[:themes]) if p.key?(:themes)
        p
      end
    end
  end
end
