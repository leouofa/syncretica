# frozen_string_literal: true

module Embeddable
  extend ActiveSupport::Concern

  included do
    has_neighbors :embedding
  end

  def embedded?
    embedding.present?
  end

  def embedding_dimensions
    Llm::EmbeddingGenerator::DIMENSIONS
  end

  def generate_embedding!
    result = Llm::EmbeddingGenerator.call(embedding_input)
    update!(
      embedding: result.fetch(:vector),
      embedding_model: result.fetch(:model),
      embedded_at: Time.current
    )
  end

  def embedding_input
    raise NotImplementedError, "#{self.class} must implement #embedding_input"
  end
end
