# frozen_string_literal: true

require "test_helper"

class ClustersControllerTest < ActionDispatch::IntegrationTest
  test "GET /clusters returns success for gods" do
    get clusters_path
    assert_response :success
    assert_select "h1", "Embedding Clusters"
    assert_select "input#similarity_level[value='5']"
  end

  test "GET /clusters with tab=myths returns success" do
    get clusters_path(tab: "myths", level: 3)
    assert_response :success
    assert_select "h1", "Embedding Clusters"
  end

  test "GET /clusters with turbo_stream format returns frame stream" do
    get clusters_path(tab: "gods", level: 4), as: :turbo_stream
    assert_response :success
    assert_includes response.body, %(turbo-stream action="update" target="clusters_content_frame")
  end

  test "GET /clusters with level=15 renders complete coverage without singletons" do
    get clusters_path(level: 15)
    assert_response :success
    assert_select "span", text: /100% Clustered/
  end

  test "GET /clusters with full_coverage=true returns complete coverage" do
    get clusters_path(level: 6, full_coverage: "true")
    assert_response :success
    assert_select "span", text: /100% Clustered/
  end

  test "POST /clusters/snapshot creates snapshot and redirects to it" do
    pantheon = Pantheon.create!(name: "Snapshot Test Pantheon", description: "Desc")
    v = Array.new(1024, 0.2)
    God.create!(pantheon: pantheon, name: "Snap God 1", description: "D1", themes: ["sky"], embedding: v)
    God.create!(pantheon: pantheon, name: "Snap God 2", description: "D2", themes: ["sky"], embedding: v)

    assert_difference "ClusterSnapshot.count", 1 do
      post snapshot_clusters_path, params: { tab: "gods", level: 5, title: "Test Controller Snapshot" }
    end

    snapshot = ClusterSnapshot.last
    assert_equal "Test Controller Snapshot", snapshot.title
    assert_redirected_to cluster_snapshot_path(snapshot)
    follow_redirect!
    assert_response :success
  end
end
