# frozen_string_literal: true

require "test_helper"

class PantheonsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "populate enqueues PopulatePantheonsJob and responds with turbo stream" do
    assert_enqueued_with(job: PopulatePantheonsJob) do
      post populate_pantheons_url, as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match "Discovering Pantheons...", response.body
  end

  test "populate enqueues PopulatePantheonsJob and redirects for HTML requests" do
    assert_enqueued_with(job: PopulatePantheonsJob) do
      post populate_pantheons_url
    end

    assert_redirected_to root_url
  end
end
