# frozen_string_literal: true

require "test_helper"

class MythTest < ActiveSupport::TestCase
  test "validates presence of god and non-empty themes hash" do
    myth = Myth.new(themes: {})
    assert_not myth.valid?
    assert_includes myth.errors[:god], "must exist"
    assert_includes myth.errors[:themes], "must be a non-empty JSON object of theme titles and descriptions"
  end

  test "enforces 1-to-1 uniqueness with god" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    zeus = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")

    Myth.create!(god: zeus, themes: { "Sovereignty" => "Ruler of the cosmos." })

    duplicate = Myth.new(god: zeus, themes: { "Justice" => "Guarantor of oaths." })
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:god_id], "has already been taken"
  end

  test "normalizes theme keys and descriptions and ignores blank entries" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    zeus = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")

    myth = Myth.create!(
      god: zeus,
      themes: {
        "  Cosmic   Order " => "  Establishing celestial rule.  ",
        "" => "Ignored blank title",
        "Blank Desc" => "   "
      }
    )

    assert_equal({ "Cosmic Order" => "Establishing celestial rule." }, myth.themes)
  end

  test "upsert_for_god! inserts and updates the god's single myth" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    zeus = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")

    created = Myth.upsert_for_god!(zeus, { "Sovereignty" => "First draft." })
    assert_equal 1, Myth.count
    assert_equal({ "Sovereignty" => "First draft." }, created.themes)

    updated = Myth.upsert_for_god!(zeus, {
      "Breaking the Generational Curse" => "Overthrowing Cronus.",
      "Arbitration of Human Destiny" => "Weighing fates on golden scales."
    })
    assert_equal 1, Myth.count
    assert_equal created.id, updated.id
    assert_equal(
      {
        "Breaking the Generational Curse" => "Overthrowing Cronus.",
        "Arbitration of Human Destiny" => "Weighing fates on golden scales."
      },
      zeus.reload.myth.themes
    )
  end

  test "grouped_by_pantheon returns myths grouped by pantheon and ordered alphabetically" do
    norse = Pantheon.create!(name: "Norse", description: "Asgardian deities.")
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")

    thor = God.create!(pantheon: norse, name: "Thor", description: "God of thunder.")
    zeus = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")
    athena = God.create!(pantheon: greek, name: "Athena", description: "Goddess of wisdom.")

    Myth.create!(god: thor, themes: { "Defense of Midgard" => "Warding off giants." })
    Myth.create!(god: zeus, themes: { "Sovereignty" => "Supreme Olympian rule." })
    Myth.create!(god: athena, themes: { "Strategic Wisdom" => "Guiding heroes in battle." })

    groups = Myth.grouped_by_pantheon
    assert_equal [ "Greek", "Norse" ], groups.map { |pantheon, _| pantheon.name }
    assert_equal [ "Athena", "Zeus" ], groups[0][1].map { |myth| myth.god.name }
    assert_equal [ "Thor" ], groups[1][1].map { |myth| myth.god.name }
  end

  test "destroying a god destroys its associated myth" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    zeus = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")
    Myth.create!(god: zeus, themes: { "Sovereignty" => "Supreme Olympian rule." })

    assert_difference("Myth.count", -1) do
      zeus.destroy!
    end
  end
end
