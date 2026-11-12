# frozen_string_literal: true

require "test_helper"

class GenerateEmbeddingJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "perform generates embedding for God and broadcasts running and success states" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(pantheon: greek, name: "Zeus", description: "King of the gods.", themes: [ "sky", "thunder" ])
    vector = Array.new(1024, 0.05)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(god), 2) do
        GenerateEmbeddingJob.perform_now("God", god.id)
      end
    end

    god.reload
    assert god.embedded?
    assert_equal "qwen3-embedding:0.6b", god.embedding_model
    assert_not_nil god.embedded_at
    assert_equal 1024, god.embedding.size
  end

  test "perform generates embedding for Myth and broadcasts running and success states" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(pantheon: greek, name: "Prometheus", description: "Titan of forethought.", themes: [ "fire" ])
    myth = Myth.create!(god: god, themes: { "Theft of Fire" => "Brought fire to humanity." })
    vector = Array.new(1024, 0.02)

    with_stubbed_generator(->(_text) { { vector: vector, model: "qwen3-embedding:0.6b" } }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(myth), 2) do
        GenerateEmbeddingJob.perform_now("Myth", myth.id)
      end
    end

    myth.reload
    assert myth.embedded?
    assert_equal "qwen3-embedding:0.6b", myth.embedding_model
    assert_not_nil myth.embedded_at
    assert_equal 1024, myth.embedding.size
  end

  test "perform broadcasts error state when embedding generation fails" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(pantheon: greek, name: "Athena", description: "Goddess of wisdom.")

    with_stubbed_generator(->(_text) { raise "Connection refused" }) do
      assert_broadcasts(GenerateEmbeddingJob.stream_name_for(god), 2) do
        GenerateEmbeddingJob.perform_now("God", god.id)
      end
    end

    assert_not god.reload.embedded?
  end

  private

  def with_stubbed_generator(replacement)
    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call, &replacement)
    yield
  ensure
    singleton.define_method(:call, original)
  end
end
