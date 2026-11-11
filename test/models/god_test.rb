# frozen_string_literal: true

require "test_helper"

class GodTest < ActiveSupport::TestCase
  test "validates presence of name, description, and pantheon" do
    god = God.new(name: " ", description: " ")
    assert_not god.valid?
    assert_includes god.errors[:pantheon], "must exist"
    assert_includes god.errors[:name], "can't be blank"
    assert_includes god.errors[:description], "can't be blank"
  end

  test "normalizes name, description, and themes" do
    pantheon = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(
      pantheon: pantheon,
      name: "  Zeus   Olympios ",
      description: "  King of the gods.  ",
      themes: [ " sky ", "Thunder", "SKY", "", nil ]
    )

    assert_equal "Zeus Olympios", god.name
    assert_equal "King of the gods.", god.description
    assert_equal [ "sky", "Thunder" ], god.themes
  end

  test "normalizes comma-separated string themes into a string array" do
    pantheon = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(
      pantheon: pantheon,
      name: "Athena",
      description: "Goddess of wisdom.",
      themes: "wisdom, warfare, crafts, Wisdom"
    )

    assert_equal [ "wisdom", "warfare", "crafts" ], god.themes
  end

  test "enforces case-insensitive uniqueness scoped per pantheon" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    roman = Pantheon.create!(name: "Roman", description: "Roman deities.")

    God.create!(pantheon: greek, name: "Apollo", description: "Greek deity of music and sun.")

    same_pantheon_dup = God.new(pantheon: greek, name: "apollo", description: "Duplicate.")
    assert_not same_pantheon_dup.valid?
    assert_includes same_pantheon_dup.errors[:name], "has already been taken"

    other_pantheon_god = God.new(pantheon: roman, name: "Apollo", description: "Roman deity of music and light.")
    assert other_pantheon_god.valid?
  end

  test "upsert_batch! inserts new gods and updates existing ones within a pantheon" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    norse = Pantheon.create!(name: "Norse", description: "Asgardian deities.")

    God.create!(pantheon: greek, name: "Zeus", description: "Old description", themes: [ "sky" ])
    God.create!(pantheon: norse, name: "Zeus", description: "Unrelated namesake", themes: [ "test" ])

    results = God.upsert_batch!(greek, [
      { "name" => "  zeus ", "description" => "King of Olympus.", "themes" => [ "sky", "thunder", "kingship" ] },
      { "name" => "Poseidon", "description" => "God of the sea.", "themes" => [ "sea", "earthquakes" ] },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Hera", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, greek.gods.count
    assert_equal 1, norse.gods.count

    greek_zeus = greek.gods.find_by!("LOWER(name) = ?", "zeus")
    assert_equal "zeus", greek_zeus.name
    assert_equal "King of Olympus.", greek_zeus.description
    assert_equal [ "sky", "thunder", "kingship" ], greek_zeus.themes

    poseidon = greek.gods.find_by!(name: "Poseidon")
    assert_equal [ "sea", "earthquakes" ], poseidon.themes
  end

  test "grouped_by_pantheon returns pantheon groups and gods sorted alphabetically" do
    norse = Pantheon.create!(name: "Norse", description: "Asgardian deities.")
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    Pantheon.create!(name: "Celtic", description: "Empty pantheon.")

    God.create!(pantheon: norse, name: "Thor", description: "God of thunder.", themes: [ "thunder" ])
    God.create!(pantheon: norse, name: "Freya", description: "Goddess of love.", themes: [ "love" ])
    God.create!(pantheon: greek, name: "Zeus", description: "Sky father.", themes: [ "sky" ])
    God.create!(pantheon: greek, name: "Athena", description: "Wisdom.", themes: [ "wisdom" ])

    groups = God.grouped_by_pantheon
    assert_equal [ "Greek", "Norse" ], groups.map { |pantheon, _| pantheon.name }
    assert_equal [ "Athena", "Zeus" ], groups[0][1].map(&:name)
    assert_equal [ "Freya", "Thor" ], groups[1][1].map(&:name)
  end

  test "destroying a pantheon destroys its associated gods" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    God.create!(pantheon: greek, name: "Zeus", description: "Sky father.", themes: [ "sky" ])

    assert_difference("God.count", -1) do
      greek.destroy!
    end
  end
end
