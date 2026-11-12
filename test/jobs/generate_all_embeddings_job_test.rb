# frozen_string_literal: true

require "test_helper"

class GenerateAllEmbeddingsJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  test "perform with only_missing: true skips already-embedded gods and embeds missing ones" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    existing_vector = Array.new(1024, 0.1)
    zeus = God.create!(
      pantheon: greek,
      name: "Zeus",
      description: "King of the gods.",
      embedding: existing_vector,
      embedding_model: "old-model",
      embedded_at: 1.day.ago
    )
    athena = God.create!(pantheon: greek, name: "Athena", description: "Goddess of wisdom.")

    new_vector = Array.new(1024, 0.2)
    called_texts = []

    with_stubbed_generator(->(text) {
      called_texts << text
      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 2) do
        GenerateAllEmbeddingsJob.perform_now("God", only_missing: true)
      end
    end

    assert_equal 1, called_texts.size
    assert_match "Athena", called_texts.first
    assert_equal "old-model", zeus.reload.embedding_model
    assert_equal "qwen3-embedding:0.6b", athena.reload.embedding_model
  end

  test "perform with only_missing: false regenerates all myths" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    zeus = God.create!(pantheon: greek, name: "Zeus", description: "King of the gods.")
    athena = God.create!(pantheon: greek, name: "Athena", description: "Goddess of wisdom.")

    myth1 = Myth.create!(
      god: zeus,
      themes: { "Sovereignty" => "Supreme rule." },
      embedding: Array.new(1024, 0.1),
      embedding_model: "old-model",
      embedded_at: 1.day.ago
    )
    myth2 = Myth.create!(god: athena, themes: { "Wisdom" => "Strategic counsel." })

    new_vector = Array.new(1024, 0.3)
    called_count = 0

    with_stubbed_generator(->(_text) {
      called_count += 1
      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 3) do
        GenerateAllEmbeddingsJob.perform_now("Myth", only_missing: false)
      end
    end

    assert_equal 2, called_count
    assert_equal "qwen3-embedding:0.6b", myth1.reload.embedding_model
    assert_equal "qwen3-embedding:0.6b", myth2.reload.embedding_model
  end

  test "perform continues remaining records when one record fails" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    zeus = God.create!(pantheon: greek, name: "Zeus", description: "King of the gods.")
    athena = God.create!(pantheon: greek, name: "Athena", description: "Goddess of wisdom.")

    new_vector = Array.new(1024, 0.4)

    with_stubbed_generator(->(text) {
      raise "Temporary timeout" if text.include?("Zeus")

      { vector: new_vector, model: "qwen3-embedding:0.6b" }
    }) do
      assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 3) do
        GenerateAllEmbeddingsJob.perform_now("God", only_missing: true)
      end
    end

    assert_not zeus.reload.embedded?
    assert athena.reload.embedded?
  end

  test "perform broadcasts info message when nothing needs embedding" do
    assert_broadcasts(GenerateAllEmbeddingsJob::STREAM_NAME, 1) do
      GenerateAllEmbeddingsJob.perform_now("God", only_missing: true)
    end
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
