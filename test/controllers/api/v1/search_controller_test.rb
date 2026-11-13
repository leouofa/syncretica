# frozen_string_literal: true

require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @pantheon = Pantheon.create!(name: "Shinto", description: "Kami and spirits of Japan.")
    @vector = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }

    @god = God.create!(
      pantheon: @pantheon,
      name: "Amaterasu",
      description: "Sun goddess of the heavenly realm Takamagahara.",
      themes: [ "sun", "celestial", "sovereignty" ],
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    @myth = Myth.create!(
      god: @god,
      themes: { "Heavenly Rock Cave" => "Amaterasu retreats into the cave plunging the universe into darkness." },
      embedding: @vector,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "GET /api/v1/search requires q parameter" do
    get api_v1_search_url, as: :json
    assert_response :bad_request
    assert_equal "blank_query", response.parsed_body.dig("error", "code")
  end

  test "GET /api/v1/search returns results for keyword search" do
    get api_v1_search_url, params: { q: "cave", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal "keyword", json.dig("meta", "mode")
  end

  test "GET /api/v1/gods/search performs keyword search" do
    get search_api_v1_gods_url, params: { q: "Amaterasu", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Amaterasu", json["data"].first["name"]
  end

  test "GET /api/v1/myths/search performs keyword search" do
    get search_api_v1_myths_url, params: { q: "darkness", mode: "keyword" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal @myth.id, json["data"].first["id"]
  end
end
