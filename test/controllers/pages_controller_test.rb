# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home renders empty state and populate button when no pantheons exist" do
    get root_url

    assert_response :success
    assert_select "h1", "Pantheons"
    assert_select "button", /Populate Pantheons/
    assert_match "No pantheons yet", response.body
  end

  test "home lists all pantheons ordered by name" do
    Pantheon.create!(name: "Norse", description: "Deities of Asgard.")
    Pantheon.create!(name: "Egyptian", description: "Deities of the Nile.")

    get root_url

    assert_response :success
    assert_select "article h2", count: 2
    assert_operator response.body.index("Egyptian"), :<, response.body.index("Norse")
    assert_match "Deities of Asgard.", response.body
    assert_match "Deities of the Nile.", response.body
  end

  test "gods renders empty state and populate button when no gods exist" do
    get gods_url

    assert_response :success
    assert_select "h1", "Gods"
    assert_select "button", /Populate Gods/
    assert_match "No gods yet", response.body
  end

  test "gods lists all gods in a table grouped by pantheon headers with themes" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    norse = Pantheon.create!(name: "Norse", description: "Asgardian deities.")

    God.create!(pantheon: norse, name: "Thor", description: "Wielder of Mjolnir.", themes: [ "thunder", "protection" ])
    God.create!(pantheon: greek, name: "Zeus", description: "Ruler of Olympus.", themes: [ "sky", "kingship" ])
    God.create!(pantheon: greek, name: "Athena", description: "Goddess of wisdom.", themes: [ "wisdom", "strategy" ])

    get gods_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Greek/
    assert_select "table tbody tr th", /Norse/
    assert_operator response.body.index("Greek"), :<, response.body.index("Norse")
    assert_operator response.body.index("Athena"), :<, response.body.index("Zeus")
    assert_match "Wielder of Mjolnir.", response.body
    assert_match "thunder", response.body
    assert_match "protection", response.body
    assert_match "kingship", response.body
  end

  test "myths renders empty state, populate button, and top navbar link when no myths exist" do
    get myths_url

    assert_response :success
    assert_select "nav a[href=?]", myths_path, text: "Myths"
    assert_select "h1", "Myths"
    assert_select "button", /Populate Myths/
    assert_match "No myths yet", response.body
  end

  test "myths lists all myths in a table grouped by pantheon headers" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    norse = Pantheon.create!(name: "Norse", description: "Asgardian deities.")

    thor = God.create!(pantheon: norse, name: "Thor", description: "Wielder of Mjolnir.")
    zeus = God.create!(pantheon: greek, name: "Zeus", description: "Ruler of Olympus.")
    athena = God.create!(pantheon: greek, name: "Athena", description: "Goddess of wisdom.")

    Myth.create!(god: thor, themes: { "Defense of Midgard" => "Protecting realms from giants." })
    Myth.create!(god: zeus, themes: { "Breaking the Generational Curse" => "Overthrowing Cronus." })
    Myth.create!(god: athena, themes: { "Strategic Wisdom" => "Guiding heroes through reason." })

    get myths_url

    assert_response :success
    assert_select "table tbody", count: 2
    assert_select "table tbody tr th", /Greek/
    assert_select "table tbody tr th", /Norse/
    assert_operator response.body.index("Greek"), :<, response.body.index("Norse")
    assert_operator response.body.index("Athena"), :<, response.body.index("Zeus")
    assert_match "Breaking the Generational Curse", response.body
    assert_match "Overthrowing Cronus.", response.body
    assert_match "Defense of Midgard", response.body
  end
end
