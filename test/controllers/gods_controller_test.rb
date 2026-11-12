# frozen_string_literal: true

require "test_helper"

class GodsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateGodsJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateGodsJob) do
      post populate_gods_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Gods...", response.body
  end

  test "populate enqueues PopulateGodsJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateGodsJob) do
      post populate_gods_url
    end

    assert_redirected_to gods_url
  end

  test "show renders god details and Generate Embedding button" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.", themes: [ "sky" ])

    get god_url(god)

    assert_response :success
    assert_match "Zeus", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.", themes: [ "sky" ])

    get god_url(god), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "Zeus", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full God Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "God", god.id ]) do
      post generate_embedding_god_url(god), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "God", god.id ]) do
      post generate_embedding_god_url(god)
    end

    assert_redirected_to god_url(god)
  end
end
