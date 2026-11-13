# frozen_string_literal: true

require "test_helper"

class Api::V1::ClusterReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @snapshot = ClusterSnapshot.create!(
      target_type: "God",
      level: 5,
      distance_threshold: 0.20,
      title: "Archetype Snapshot",
      clusters_count: 1,
      items_count: 2
    )
    @group = @snapshot.cluster_groups.create!(name: "Solar Deities", shared_themes: [ "sun" ], size: 2)

    @report = @snapshot.cluster_reports.create!(
      prompt: "Analyze solar sovereignty",
      status: "completed",
      phase: ClusterReport::PHASE_COMPLETED,
      content: "# Solar Analysis\nMonograph on sun deities."
    )
    @summary = @report.cluster_report_summaries.create!(
      cluster_group: @group,
      position: 1,
      content: "Solar analysis for group 1"
    )
  end

  test "GET /api/v1/cluster_reports returns list" do
    get api_v1_cluster_reports_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal @report.id, json["data"].first["id"]
  end

  test "GET /api/v1/cluster_reports/:id returns report with summaries" do
    get api_v1_cluster_report_url(@report), params: { include_summaries: "true" }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @report.id, json.dig("data", "id")
    assert_equal 1, json.dig("data", "summaries").size
    assert_equal "Solar analysis for group 1", json.dig("data", "summaries").first["content"]
  end

  test "POST /api/v1/cluster_reports creates report and enqueues job" do
    assert_enqueued_with(job: GenerateClusterReportJob) do
      post api_v1_cluster_reports_url, params: {
        cluster_snapshot_id: @snapshot.id,
        prompt: "Cross-pantheon trickster motifs"
      }, as: :json
    end
    assert_response :created

    json = response.parsed_body
    assert_equal "Cross-pantheon trickster motifs", json.dig("data", "prompt")
    assert json.dig("meta", "job_id").present?
  end

  test "POST /api/v1/cluster_reports/:id/deep_synthesis creates child report and enqueues job" do
    assert_enqueued_with(job: GenerateClusterReportJob) do
      post deep_synthesis_api_v1_cluster_report_url(@report), params: { batch_size: 5 }, as: :json
    end
    assert_response :created

    json = response.parsed_body
    assert_equal true, json.dig("data", "is_detailed")
    assert_equal @report.id, json.dig("data", "parent_report_id")
  end

  test "DELETE /api/v1/cluster_reports/:id removes report" do
    assert_difference("ClusterReport.count", -1) do
      delete api_v1_cluster_report_url(@report), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/cluster_reports/:cluster_report_id/summaries returns summaries" do
    get api_v1_cluster_report_summaries_url(@report), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal @summary.id, json["data"].first["id"]
  end

  test "GET /api/v1/cluster_report_summaries/:id returns summary" do
    get api_v1_cluster_report_summary_url(@summary), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal @summary.id, json.dig("data", "id")
  end
end
