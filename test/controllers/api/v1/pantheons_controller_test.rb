# frozen_string_literal: true

require "test_helper"

class Api::V1::PantheonsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @pantheon = Pantheon.create!(name: "Celtic", description: "Celtic deities and druidic lore.")
  end

  test "GET /api/v1/pantheons returns list" do
    get api_v1_pantheons_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert json["meta"].key?("total")
    names = json["data"].map { |p| p["name"] }
    assert_includes names, "Celtic"
  end

  test "GET /api/v1/pantheons/:id returns single pantheon" do
    get api_v1_pantheon_url(@pantheon), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @pantheon.name, json.dig("data", "name")
  end

  test "POST /api/v1/pantheons creates a new pantheon" do
    assert_difference("Pantheon.count", 1) do
      post api_v1_pantheons_url, params: { pantheon: { name: "Slavic", description: "Deities of the Slavs." } }, as: :json
    end
    assert_response :created

    json = response.parsed_body
    assert_equal "Slavic", json.dig("data", "name")
  end

  test "PATCH /api/v1/pantheons/:id updates a pantheon" do
    patch api_v1_pantheon_url(@pantheon), params: { pantheon: { description: "Updated description" } }, as: :json
    assert_response :success

    @pantheon.reload
    assert_equal "Updated description", @pantheon.description
  end

  test "DELETE /api/v1/pantheons/:id removes a pantheon" do
    assert_difference("Pantheon.count", -1) do
      delete api_v1_pantheon_url(@pantheon), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "POST /api/v1/pantheons/upsert_batch upserts multiple pantheons" do
    payload = {
      pantheons: [
        { name: "Celtic", description: "New Celtic description" },
        { name: "Incan", description: "Deities of the Andes" }
      ]
    }

    assert_difference("Pantheon.count", 1) do
      post upsert_batch_api_v1_pantheons_url, params: payload, as: :json
    end
    assert_response :success

    assert_equal "New Celtic description", @pantheon.reload.description
    assert Pantheon.find_by(name: "Incan")
  end

  test "POST /api/v1/pantheons/populate enqueues PopulatePantheonsJob by default" do
    assert_enqueued_with(job: PopulatePantheonsJob) do
      post populate_api_v1_pantheons_url, as: :json
    end
    assert_response :accepted
    assert response.parsed_body.dig("data", "job_id").present?
  end

  test "POST /api/v1/pantheons/:id/populate_gods enqueues PopulateGodsJob" do
    assert_enqueued_with(job: PopulateGodsJob, args: [ { pantheon_id: @pantheon.id } ]) do
      post populate_gods_api_v1_pantheon_url(@pantheon), as: :json
    end
    assert_response :accepted
  end
end
