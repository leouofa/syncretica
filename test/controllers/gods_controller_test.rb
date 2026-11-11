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
end
