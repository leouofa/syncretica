# frozen_string_literal: true

require "test_helper"

class PantheonTest < ActiveSupport::TestCase
  test "validates presence of name and description" do
    pantheon = Pantheon.new(name: " ", description: " ")
    assert_not pantheon.valid?
    assert_includes pantheon.errors[:name], "can't be blank"
    assert_includes pantheon.errors[:description], "can't be blank"
  end

  test "normalizes name whitespace and enforces case-insensitive uniqueness" do
    first = Pantheon.create!(name: "  Greek   Mythology ", description: "Olympian gods.")
    assert_equal "Greek Mythology", first.name

    duplicate = Pantheon.new(name: "greek mythology", description: "Duplicate.")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "upsert_batch! inserts new pantheons and updates existing ones case-insensitively" do
    Pantheon.create!(name: "Greek", description: "Old description")

    results = Pantheon.upsert_batch!([
      { "name" => "  greek ", "description" => "Updated Olympian pantheon." },
      { "name" => "Norse", "description" => "Aesir and Vanir deities of Scandinavia." },
      { "name" => "", "description" => "Ignored blank name" },
      { "name" => "Celtic", "description" => "   " }
    ])

    assert_equal 2, results.size
    assert_equal 2, Pantheon.count

    greek = Pantheon.find_by!("LOWER(name) = ?", "greek")
    assert_equal "greek", greek.name
    assert_equal "Updated Olympian pantheon.", greek.description

    norse = Pantheon.find_by!(name: "Norse")
    assert_equal "Aesir and Vanir deities of Scandinavia.", norse.description
  end
end
