# frozen_string_literal: true

module Api
  module V1
    class MythsController < BaseController
      before_action :set_myth, only: %i[show update destroy neighbors generate_embedding]

      def index
        scope = Myth.includes(god: :pantheon)
        scope = scope.where(god_id: params[:god_id]) if params[:god_id].present?
        if params[:pantheon_id].present?
          scope = scope.joins(:god).where(gods: { pantheon_id: params[:pantheon_id] })
        end

        if params[:theme].present?
          scope = scope.where("EXISTS (SELECT 1 FROM jsonb_each_text(myths.themes) kv WHERE kv.key ILIKE :t OR kv.value ILIKE :t)", t: "%#{params[:theme]}%")
        end

        if params[:q].present?
          scope = scope.joins(:god).where("gods.name ILIKE :q OR EXISTS (SELECT 1 FROM jsonb_each_text(myths.themes) kv WHERE kv.key ILIKE :q OR kv.value ILIKE :q)", q: "%#{params[:q]}%")
        end

        if params.key?(:embedded)
          scope = boolean_param(:embedded) ? scope.where.not(embedding: nil) : scope.where(embedding: nil)
        end

        records, meta = paginate(scope.order("myths.id ASC"))

        include_embedding = boolean_param(:include_embedding, default: false)
        data = records.map do |myth|
          Serializer.myth(myth, include_embedding: include_embedding, include_god: true)
        end

        render_success(data, meta: meta)
      end

      def search
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = Myth.includes(god: :pantheon)
        if params[:pantheon_id].present?
          scope = scope.joins(:god).where(gods: { pantheon_id: params[:pantheon_id] })
        end

        if (mode == "semantic" || mode == "auto") && scope.where.not(embedding: nil).exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            neighbors = scope.where.not(embedding: nil)
                             .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                             .limit(limit)

            results = neighbors.map do |myth|
              dist = myth.try(:neighbor_distance)
              Serializer.myth(myth, neighbor_distance: dist)
            end

            return render_success(results, meta: { mode: "semantic", query: query, count: results.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        keyword_matches = scope.joins(:god)
                               .where("gods.name ILIKE :q OR EXISTS (SELECT 1 FROM jsonb_each_text(myths.themes) kv WHERE kv.key ILIKE :q OR kv.value ILIKE :q)", q: "%#{query}%")
                               .limit(limit)

        results = keyword_matches.map { |m| Serializer.myth(m) }
        render_success(results, meta: { mode: "keyword", query: query, count: results.size })
      end

      def show
        render_success(
          Serializer.myth(@myth, include_embedding: boolean_param(:include_embedding, default: false), include_god: true)
        )
      end

      def create
        god = God.find(params.require(:myth).require(:god_id))
        themes = params.require(:myth).require(:themes).to_unsafe_h
        myth = Myth.upsert_for_god!(god, themes)
        render_success(Serializer.myth(myth), status: :created)
      end

      def update
        themes = params.require(:myth).require(:themes).to_unsafe_h
        normalized = Myth.normalize_themes(themes)
        return render_error(code: "invalid_themes", message: "themes must not be empty") if normalized.empty?

        @myth.update!(themes: normalized)
        render_success(Serializer.myth(@myth))
      end

      def destroy
        @myth.destroy!
        render_success({ id: @myth.id, god_id: @myth.god_id, deleted: true })
      end

      def neighbors
        unless @myth.embedded?
          return render_error(code: "not_embedded", message: "Myth does not have an embedding yet")
        end

        limit = (params[:limit].presence || 10).to_i.clamp(1, 100)
        scope = Myth.includes(god: :pantheon).where.not(id: @myth.id)
        if params[:pantheon_id].present?
          scope = scope.joins(:god).where(gods: { pantheon_id: params[:pantheon_id] })
        end

        neighbors = scope.nearest_neighbors(:embedding, @myth.embedding, distance: "cosine").limit(limit)
        results = neighbors.map do |neighbor|
          Serializer.myth(neighbor, neighbor_distance: neighbor.try(:neighbor_distance))
        end

        render_success(results, meta: { myth_id: @myth.id, count: results.size })
      end

      def generate_embedding
        if sync_requested?
          @myth.generate_embedding!
          render_success(Serializer.myth(@myth, include_embedding: boolean_param(:include_embedding, default: false)))
        else
          job = GenerateEmbeddingJob.perform_later("Myth", @myth.id)
          render_success({ job_id: job.job_id, status: "queued", myth_id: @myth.id }, status: :accepted)
        end
      end

      def populate
        god_id = params[:god_id].presence
        if sync_requested?
          result = PopulateMythsJob.new.perform(god_id: god_id)
          render_success({ message: "Myths populated", result: result })
        else
          job = PopulateMythsJob.perform_later(god_id: god_id)
          render_success({ job_id: job.job_id, status: "queued", god_id: god_id }, status: :accepted)
        end
      end

      private

      def set_myth
        @myth = Myth.includes(god: :pantheon).find(params[:id])
      end
    end
  end
end
