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

  test "should create a detailed report and enqueue job" do
    assert_enqueued_with(job: GenerateClusterReportJob) do
      post deep_synthesis_cluster_report_url(@report), params: { batch_size: 10 }
    end

    created = ClusterReport.last
    assert created.detailed?
    assert_equal 10, created.batch_size
    assert_equal @report.prompt, created.prompt
    assert_equal "pending", created.status
    assert_equal @snapshot, created.cluster_snapshot
    assert_redirected_to cluster_report_url(created)
  end

  test "deep synthesis clamps batch size to the allowed range" do
    post deep_synthesis_cluster_report_url(@report), params: { batch_size: 999 }
    assert_equal ClusterReport::BATCH_SIZE_RANGE.max, ClusterReport.last.batch_size

    post deep_synthesis_cluster_report_url(@report), params: { batch_size: 1 }
    assert_equal ClusterReport::BATCH_SIZE_RANGE.min, ClusterReport.last.batch_size
  end

  test "deep synthesis defaults batch size when missing" do
    post deep_synthesis_cluster_report_url(@report)
    assert_equal ClusterReport::DEFAULT_BATCH_SIZE, ClusterReport.last.batch_size
  end

  test "should render a detailed report with batch analyses" do
    group = @snapshot.cluster_groups.create!(name: "Solar Realm", shared_themes: [ "sun" ], size: 1)
    @report.update!(is_detailed: true, batch_size: 5)
    @report.cluster_report_summaries.create!(cluster_group: group, position: 1, content: "Cluster analysis")
    @report.cluster_sub_reports.create!(batch_index: 1, cluster_group_ids: [ group.id ], content: "Batch narrative")

    get cluster_report_url(@report)
    assert_response :success
    assert_includes response.body, "Batch Analyses"
    assert_includes response.body, "Batch #1"
    assert_includes response.body, "Detailed Synthesis"
  end
end
