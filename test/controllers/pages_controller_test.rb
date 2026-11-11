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
end
