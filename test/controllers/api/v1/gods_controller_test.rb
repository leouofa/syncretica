# frozen_string_literal: true

require "test_helper"

class Api::V1::GodsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @pantheon = Pantheon.create!(name: "Roman", description: "Roman religion and cults.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.99 : 0.01 }

    @god = God.create!(
      pantheon: @pantheon,
      name: "Jupiter",
      description: "King of the gods, god of the sky and thunder.",
      themes: [ "sky", "thunder", "kingship" ],
      embedding: @vector_a,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/gods returns list with filtering" do
    get api_v1_gods_url, params: { pantheon_id: @pantheon.id, theme: "thunder" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Jupiter", json["data"].first["name"]
    assert_equal false, json["data"].first.key?("embedding")
  end

  test "GET /api/v1/gods/:id returns god with pantheon and myth details" do
    get api_v1_god_url(@god), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "Jupiter", json.dig("data", "name")
    assert_equal "Roman", json.dig("data", "pantheon", "name")
  end

  test "GET /api/v1/gods/:id with include_embedding=true returns raw vector" do
    get api_v1_god_url(@god), params: { include_embedding: "true" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json.dig("data", "embedding").is_a?(Array)
    assert_equal 1024, json.dig("data", "embedding").size
  end

  test "POST /api/v1/gods creates a god" do
    assert_difference("God.count", 1) do
      post api_v1_gods_url, params: {
        god: {
          pantheon_id: @pantheon.id,
          name: "Mars",
          description: "God of war and agriculture guardian.",
          themes: [ "war", "valor" ]
        }
      }, as: :json
    end
    assert_response :created
    assert_equal "Mars", response.parsed_body.dig("data", "name")
  end

  test "PATCH /api/v1/gods/:id updates god" do
    patch api_v1_god_url(@god), params: { god: { description: "Updated Jupiter description" } }, as: :json
    assert_response :success
    assert_equal "Updated Jupiter description", @god.reload.description
  end

  test "DELETE /api/v1/gods/:id deletes god" do
    assert_difference("God.count", -1) do
      delete api_v1_god_url(@god), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/gods/:id/neighbors finds nearest gods" do
    other = God.create!(
      pantheon: @pantheon,
      name: "Tempestas",
      description: "Goddess of storms and weather.",
      themes: [ "storm" ],
      embedding: @vector_b,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    get neighbors_api_v1_god_url(@god), params: { limit: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "Tempestas", json["data"].first["name"]
    assert json["data"].first["neighbor_distance"].present?
  end

  test "POST /api/v1/gods/:id/generate_embedding enqueues job" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      post generate_embedding_api_v1_god_url(@god), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end

  test "POST /api/v1/gods/:id/populate_myth enqueues job" do
    assert_enqueued_with(job: PopulateMythsJob) do
      post populate_myth_api_v1_god_url(@god), params: { sync: "false" }, as: :json
    end
    assert_response :accepted
  end
end
