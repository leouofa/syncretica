# frozen_string_literal: true

require "test_helper"

class SnapshotDigestBuilderTest < ActiveSupport::TestCase
  test "builds digest for God snapshot" do
    pantheon = Pantheon.create!(name: "Test Pantheon", description: "Desc")
    god1 = God.create!(pantheon: pantheon, name: "Solaris", description: "Sun god", themes: [ "sun", "light" ])
    god2 = God.create!(pantheon: pantheon, name: "Astra", description: "Star deity", themes: [ "stars", "night" ])

    snapshot = ClusterSnapshot.create!(
      target_type: "God",
      level: 5,
      distance_threshold: 0.20,
      title: "Solar Pantheon",
      clusters_count: 1,
      items_count: 2
    )

    group = snapshot.cluster_groups.create!(name: "Celestial Lights", shared_themes: [ "sky", "light" ], size: 2)
    group.cluster_memberships.create!(record: god1)
    group.cluster_memberships.create!(record: god2)

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, max_chars: 10_000)

    assert_includes digest, "=== CLUSTER SNAPSHOT OVERVIEW ==="
    assert_includes digest, "Solar Pantheon"
    assert_includes digest, "Target Type: God"
    assert_includes digest, "Celestial Lights"
    assert_includes digest, "Solaris (Test Pantheon)"
    assert_includes digest, "Astra (Test Pantheon)"
  end

  test "builds digest for Myth snapshot" do
    pantheon = Pantheon.create!(name: "Norse Test", description: "Norse desc")
    god = God.create!(pantheon: pantheon, name: "Thor Test", description: "Thunder god", themes: [ "thunder" ])
    myth = Myth.create!(god: god, themes: { "Hammer Retrieval" => "Retrieving Mjolnir from giants." })

    snapshot = ClusterSnapshot.create!(
      target_type: "Myth",
      level: 10,
      distance_threshold: 0.25,
      title: "Myth Clusters",
      clusters_count: 1,
      items_count: 1
    )

    group = snapshot.cluster_groups.create!(name: "Cosmic Relics", shared_themes: [ "weapons" ], size: 1)
    group.cluster_memberships.create!(record: myth)

    report = snapshot.cluster_reports.create!(prompt: "Analyze relics")
    report.cluster_report_summaries.create!(
      cluster_group: group,
      content: "This cluster focuses on sovereign implements of thunder and power.",
      position: 1
    )

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, report: report, max_chars: 5_000)

    assert_includes digest, "Target Type: Myth"
    assert_includes digest, "Thor Test Myth (Norse Test)"
    assert_includes digest, "Hammer Retrieval"
    assert_includes digest, "Prompt-Guided Cluster Analysis:"
    assert_includes digest, "sovereign implements of thunder and power"
  end
end
