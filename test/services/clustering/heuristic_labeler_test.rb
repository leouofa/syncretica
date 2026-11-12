# frozen_string_literal: true

require "test_helper"

class HeuristicLabelerTest < ActiveSupport::TestCase
  test "labels an empty list of records" do
    result = Clustering::HeuristicLabeler.label([])
    assert_equal "Empty Cluster", result[:title]
    assert_empty result[:shared_themes]
  end

  test "extracts shared themes and builds archetype title for gods" do
    pantheon = Pantheon.create!(name: "Test Pantheon 1", description: "Test")
    g1 = God.create!(pantheon: pantheon, name: "Zeus Alpha", description: "Sky", themes: %w[thunder sky storms])
    g2 = God.create!(pantheon: pantheon, name: "Jupiter Beta", description: "Sky", themes: %w[thunder sky lightning])

    result = Clustering::HeuristicLabeler.label([ g1, g2 ])
    assert_includes result[:shared_themes], "Thunder"
    assert_includes result[:shared_themes], "Sky"
    assert_includes result[:title], "Domain"
  end

  test "extracts shared themes for myths" do
    pantheon = Pantheon.create!(name: "Test Pantheon 2", description: "Test")
    god = God.create!(pantheon: pantheon, name: "Odin Gamma", description: "Allfather", themes: [ "wisdom" ])
    myth = Myth.create!(god: god, themes: { "Creation" => "Formed the cosmos", "Wisdom" => "Sacrificed eye" })

    result = Clustering::HeuristicLabeler.label([ myth ])
    assert_includes result[:shared_themes], "Creation"
    assert_includes result[:shared_themes], "Wisdom"
  end
end
