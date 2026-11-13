# frozen_string_literal: true

require "test_helper"

class Api::V1::StatusAndOpenapiControllerTest < ActionDispatch::IntegrationTest
  test "GET /api/v1/status returns ok status and platform stats" do
    get api_v1_status_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "ok", json.dig("data", "status")
    assert json.dig("data", "counts").key?("gods")
    assert json.dig("data", "counts").key?("pantheons")
    assert json.dig("data", "config").key?("context_window")
  end

  test "GET /api/v1/openapi returns valid OpenAPI 3.1 schema" do
    get api_v1_openapi_spec_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "3.1.0", json["openapi"]
    assert_equal "Syncretica Platform REST API", json.dig("info", "title")
    assert json["paths"].key?("/status")
    assert json["paths"].key?("/pantheons")
    assert json["paths"].key?("/gods")
    assert json["paths"].key?("/myths")
    assert json["paths"].key?("/clusters")
    assert json["paths"].key?("/cluster_snapshots")
    assert json["paths"].key?("/cluster_reports")
  end
end
