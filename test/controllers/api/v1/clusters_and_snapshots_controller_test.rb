# frozen_string_literal: true

require "test_helper"

class Api::V1::ClustersAndSnapshotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @pantheon = Pantheon.create!(name: "Greek", description: "Olympian gods.")
    @vector_a = Array.new(1024) { |i| i == 0 ? 1.0 : 0.0 }
    @vector_b = Array.new(1024) { |i| i == 0 ? 0.99 : 0.01 }

    @god_a = God.create!(pantheon: @pantheon, name: "Zeus", description: "King of gods", themes: [ "sky" ], embedding: @vector_a, embedding_model: "qwen3-embedding:0.6b", embedded_at: Time.current)
    @god_b = God.create!(pantheon: @pantheon, name: "Poseidon", description: "God of seas", themes: [ "water" ], embedding: @vector_b, embedding_model: "qwen3-embedding:0.6b", embedded_at: Time.current)

    @snapshot = ClusterSnapshot.create!(
      target_type: "God",
      level: 5,
      distance_threshold: 0.20,
      title: "Olympian Core Snapshot",
      clusters_count: 1,
      items_count: 2
    )
    @group = @snapshot.cluster_groups.create!(name: "Sky Domain", shared_themes: [ "sky" ], size: 2)
    @group.cluster_memberships.create!(record: @god_a)
    @group.cluster_memberships.create!(record: @god_b)
  end

  test "GET /api/v1/clusters returns live cluster computation" do
    get api_v1_clusters_url, params: { target_type: "God", level: 5 }, as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "God", json.dig("data", "target_type")
    assert json.dig("data", "clusters").is_a?(Array)
  end

  test "POST /api/v1/clusters/snapshot persists a snapshot" do
    assert_difference("ClusterSnapshot.count", 1) do
      post snapshot_api_v1_clusters_url, params: { target_type: "God", level: 5, title: "Custom Snapshot" }, as: :json
    end
    assert_response :created

    json = response.parsed_body
    assert_equal "Custom Snapshot", json.dig("data", "title")
    assert json.dig("data", "groups").is_a?(Array)
  end

  test "GET /api/v1/cluster_snapshots returns list" do
    get api_v1_cluster_snapshots_url, as: :json
    assert_response :success

    json = response.parsed_body
    assert json["data"].is_a?(Array)
    assert_equal @snapshot.id, json["data"].first["id"]
  end

  test "GET /api/v1/cluster_snapshots/:id returns snapshot with groups and members" do
    get api_v1_cluster_snapshot_url(@snapshot), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "Olympian Core Snapshot", json.dig("data", "title")
    assert_equal 1, json.dig("data", "groups").size
    assert_equal 2, json.dig("data", "groups").first.dig("members").size
  end

  test "DELETE /api/v1/cluster_snapshots/:id deletes snapshot" do
    assert_difference("ClusterSnapshot.count", -1) do
      delete api_v1_cluster_snapshot_url(@snapshot), as: :json
    end
    assert_response :success
    assert response.parsed_body.dig("data", "deleted")
  end

  test "GET /api/v1/cluster_snapshots/:cluster_snapshot_id/cluster_groups lists snapshot groups" do
    get api_v1_cluster_snapshot_cluster_groups_url(@snapshot), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal 1, json["data"].size
    assert_equal "Sky Domain", json["data"].first["name"]
  end

  test "GET /api/v1/cluster_groups/:id returns group with members" do
    get api_v1_cluster_group_url(@group), as: :json
    assert_response :success

    json = response.parsed_body
    assert_equal "Sky Domain", json.dig("data", "name")
    assert_equal 2, json.dig("data", "members").size
  end
end
