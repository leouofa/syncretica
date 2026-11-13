# frozen_string_literal: true

module Api
  module V1
    class SearchController < BaseController
      def index
        query = params[:q].to_s.strip
        return render_error(code: "blank_query", message: "Query parameter 'q' must not be blank") if query.blank?

        target_type = params[:target_type].to_s.downcase.presence || "all"
        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        gods_scope = God.includes(:pantheon)
        myths_scope = Myth.includes(god: :pantheon)

        if (mode == "semantic" || mode == "auto") && (gods_scope.where.not(embedding: nil).exists? || myths_scope.where.not(embedding: nil).exists?)
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            god_results = []
            if %w[all god].include?(target_type)
              god_results = gods_scope.where.not(embedding: nil)
                                      .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                      .limit(limit)
                                      .map do |god|
                                        {
                                          type: "God",
                                          score: 1.0 - god.try(:neighbor_distance).to_f,
                                          data: Serializer.god(god, neighbor_distance: god.try(:neighbor_distance))
                                        }
                                      end
            end

            myth_results = []
            if %w[all myth].include?(target_type)
              myth_results = myths_scope.where.not(embedding: nil)
                                        .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                                        .limit(limit)
                                        .map do |myth|
                                          {
                                            type: "Myth",
                                            score: 1.0 - myth.try(:neighbor_distance).to_f,
                                            data: Serializer.myth(myth, neighbor_distance: myth.try(:neighbor_distance))
                                          }
                                        end
            end

            combined = (god_results + myth_results).sort_by { |item| -item[:score] }.take(limit)
            return render_success(combined, meta: { mode: "semantic", query: query, count: combined.size })
          rescue StandardError => e
            raise e if mode == "semantic"
          end
        end

        # Keyword fallback
        god_kw = []
        if %w[all god].include?(target_type)
          god_kw = gods_scope.where("gods.name ILIKE :q OR gods.description ILIKE :q", q: "%#{query}%")
                             .limit(limit)
                             .map { |g| { type: "God", data: Serializer.god(g) } }
        end

        myth_kw = []
        if %w[all myth].include?(target_type)
          myth_kw = myths_scope.joins(:god)
                               .where("gods.name ILIKE :q OR EXISTS (SELECT 1 FROM jsonb_each_text(myths.themes) kv WHERE kv.key ILIKE :q OR kv.value ILIKE :q)", q: "%#{query}%")
                               .limit(limit)
                               .map { |m| { type: "Myth", data: Serializer.myth(m) } }
        end

        combined = (god_kw + myth_kw).take(limit)
        render_success(combined, meta: { mode: "keyword", query: query, count: combined.size })
      end
    end
  end
end
