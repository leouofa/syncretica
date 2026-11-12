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
end
