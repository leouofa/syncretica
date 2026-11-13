# frozen_string_literal: true

require "test_helper"

class Api::V1::MythsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @pantheon = Pantheon.create!(name: "Mesopotamian", description: "Deities of Sumer and Babylon.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.98 : 0.02 }

    @god = God.create!(pantheon: @pantheon, name: "Marduk", description: "Champion of Babylon.", themes: [ "chaoskampf" ])
    @other_god = God.create!(pantheon: @pantheon, name: "Tiamat", description: "Primordial sea dragon.", themes: [ "chaos" ])

    @myth = Myth.create!(
      god: @god,
      themes: { "Enuma Elish" => "Marduk slays Tiamat and creates heaven and earth." },
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/myths returns list" do
    get api_v1_myths_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal 1, json["data"].size
    assert_equal "Marduk", json["data"].first.dig("god", "name")
  end

  test "GET /api/v1/myths/:id returns myth" do
    get api_v1_myth_url(@myth), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @myth.id, json.dig("data", "id")
    assert json.dig("data", "themes").key?("Enuma Elish")
  end

  test "POST /api/v1/myths creates myth for a god" do
    assert_difference("Myth.count", 1) do
      post api_v1_myths_url, params: {
        myth: {
          god_id: @other_god.id,
          themes: { "Primordial Chaos" => "Tiamat represents the salt waters of chaos." }
        }
      }, as: :json
    end
    assert_response :created
    assert_equal @other_god.id, response.parsed_body.dig("data", "god_id")
  end

  test "PATCH /api/v1/myths/:id updates themes" do
    patch api_v1_myth_url(@myth), params: {
      myth: {
        themes: { "Cosmic Sovereignty" => "Marduk rises above the pantheon." }
      }
    }, as: :json
    assert_response :success
    assert_equal "Marduk rises above the pantheon.", @myth.reload.themes["Cosmic Sovereignty"]
  end

  test "DELETE /api/v1/myths/:id deletes myth" do
    assert_difference("Myth.count", -1) do
      delete api_v1_myth_url(@myth), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/myths/:id/neighbors finds nearest myths" do
    other_myth = Myth.create!(
      god: @other_god,
      themes: { "Salt Waters" => "Tiamat mixes with Abzu." },
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_myth_url(@myth), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal other_myth.id, json["data"].first["id"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/myths/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_myth_url(@myth), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end
