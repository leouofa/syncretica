# frozen_string_literal: true

require "test_helper"

class Api::V1::SettingsAndJobsControllerTest < ActionDispatch::IntegrationTest
  test "GET /api/v1/settings returns configuration and embedding statistics" do
    get api_v1_settings_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json.dig("data", "god_stats").key?("total")
    assert json.dig("data", "embedding_config").key?("model")
    assert json.dig("data", "llm_config").key?("context_window")
  end

  test "PATCH /api/v1/settings/context_window updates context window tokens" do
    patch context_window_api_v1_settings_url, params: { context_window: 131072 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 131072, json.dig("data", "context_window")
  end

  test "POST /api/v1/settings/generate_embeddings enqueues bulk embedding job" do
    assert_enqueued_with(job: GenerateAllEmbeddingsJob) do
      post generate_embeddings_api_v1_settings_url, params: { model_type: "God", only_missing: true }, as: :json
    end
    assert_response :accepted

    json = response.parsed_body
    assert json.dig("data", "job_id").present?
  end

  test "GET /api/v1/jobs/:id returns tracked job status" do
    Api::JobStatusTracker.record_enqueued("test-job-123", job_class: "PopulateGodsJob", arguments: [])

    get api_v1_job_url("test-job-123"), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "test-job-123", json.dig("data", "job_id")
    assert_equal "queued", json.dig("data", "status")
  end

  test "GET /api/v1/jobs lists recent jobs" do
    Api::JobStatusTracker.record_enqueued("test-job-recent", job_class: "PopulatePantheonsJob", arguments: [])

    get api_v1_jobs_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    job_ids = json["data"].map { |j| j["job_id"] }
    assert_includes job_ids, "test-job-recent"
  end
end
