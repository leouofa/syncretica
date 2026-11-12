# frozen_string_literal: true

require "test_helper"

class ClusterSnapshotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @snapshot = ClusterSnapshot.create!(
      target_type: "God",
      level: 4,
      distance_threshold: 0.20,
      title: "Fixture Snapshot",
      clusters_count: 2,
      items_count: 5
    )
  end

  test "GET /cluster_snapshots lists snapshots" do
    get cluster_snapshots_path
    assert_response :success
    assert_select "h1", "Saved Cluster Snapshots"
    assert_select "td", text: /Fixture Snapshot/
  end

  test "GET /cluster_snapshots/:id shows snapshot details" do
    get cluster_snapshot_path(@snapshot)
    assert_response :success
    assert_select "h1", @snapshot.title
  end

  test "DELETE /cluster_snapshots/:id deletes snapshot" do
    assert_difference "ClusterSnapshot.count", -1 do
      delete cluster_snapshot_path(@snapshot)
    end
    assert_redirected_to cluster_snapshots_path
  end
end
