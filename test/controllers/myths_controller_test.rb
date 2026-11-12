# frozen_string_literal: true

require "test_helper"

class MythsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulateMythsJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulateMythsJob) do
      post populate_myths_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Myths...", response.body
  end

  test "populate enqueues PopulateMythsJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulateMythsJob) do
      post populate_myths_url
    end

    assert_redirected_to myths_url
  end

  test "show renders myth details and Generate Embedding button" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")
    myth = Myth.create!(god: god, themes: { "Sovereignty" => "Supreme Olympian rule." })

    get myth_url(myth)

    assert_response :success
    assert_match "Myths of Zeus", response.body
    assert_match "Generate Embedding", response.body
    assert_match "Not generated", response.body
  end

  test "show with Turbo-Frame cluster_modal renders modal partial" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")
    myth = Myth.create!(god: god, themes: { "Sovereignty" => "Supreme Olympian rule." })

    get myth_url(myth), headers: { "Turbo-Frame" => "cluster_modal" }

    assert_response :success
    assert_select "turbo-frame#cluster_modal"
    assert_match "Myths of Zeus", response.body
    assert_match "Back to Clusters", response.body
    assert_match "Open Full Myth Page", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and responds with turbo stream" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")
    myth = Myth.create!(god: god, themes: { "Sovereignty" => "Supreme Olympian rule." })

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "Myth", myth.id ]) do
      post generate_embedding_myth_url(myth), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Generating Embedding...", response.body
  end

  test "generate_embedding enqueues GenerateEmbeddingJob and redirects for HTML requests" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    god = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")
    myth = Myth.create!(god: god, themes: { "Sovereignty" => "Supreme Olympian rule." })

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ "Myth", myth.id ]) do
      post generate_embedding_myth_url(myth)
    end

    assert_redirected_to myth_url(myth)
  end
end
