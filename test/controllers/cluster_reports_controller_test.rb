# frozen_string_literal: true

require "test_helper"

class ClusterReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @snapshot = ClusterSnapshot.create!(
      target_type: "God",
      level: 5,
      distance_threshold: 0.20,
      title: "Solar Snapshot",
      clusters_count: 1,
      items_count: 2
    )
    @report = @snapshot.cluster_reports.create!(
      prompt: "Find interesting patterns across myths or gods",
      status: "completed",
      content: "# Patterns Found\nContent here."
    )
  end

  test "should get index" do
    get cluster_reports_url
    assert_response :success
    assert_select "h1", /LLM Archetype & Pattern Reports/
  end

  test "should filter index by target_type" do
    get cluster_reports_url(target_type: "God")
    assert_response :success
    assert_includes response.body, "Solar Snapshot"
  end

  test "should show report" do
    get cluster_report_url(@report)
    assert_response :success
    assert_includes response.body, "Patterns Found"
  end

  test "should create report and enqueue job" do
    assert_enqueued_with(job: GenerateClusterReportJob) do
      post cluster_snapshot_cluster_reports_url(@snapshot), params: {
        cluster_report: { prompt: "Analyze chaos vs order" }
      }
    end

    assert_redirected_to cluster_snapshot_url(@snapshot)
    created = ClusterReport.last
    assert_equal "Analyze chaos vs order", created.prompt
    assert_equal "pending", created.status
  end

  test "should destroy report" do
    assert_difference("ClusterReport.count", -1) do
      delete cluster_report_url(@report)
    end
    assert_redirected_to cluster_snapshot_url(@snapshot)
  end
end
