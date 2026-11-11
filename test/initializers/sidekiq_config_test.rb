# frozen_string_literal: true

require "test_helper"
require "erb"
require "yaml"

class SidekiqConfigTest < ActiveSupport::TestCase
  test "configures redis url from ENV with localhost fallback" do
    previous_redis_url = ENV["REDIS_URL"]

    ENV["REDIS_URL"] = "redis://redis.example.com:6379/2"
    load Rails.root.join("config/initializers/sidekiq.rb")
    pool = Sidekiq.default_configuration.new_redis_pool(1)
    assert_equal [ "redis.example.com", 6379, 2 ], pool.with { |c| [ c.config.host, c.config.port, c.config.db ] }

    ENV.delete("REDIS_URL")
    load Rails.root.join("config/initializers/sidekiq.rb")
    pool = Sidekiq.default_configuration.new_redis_pool(1)
    assert_equal [ "localhost", 6379, 0 ], pool.with { |c| [ c.config.host, c.config.port, c.config.db ] }
  ensure
    previous_redis_url.nil? ? ENV.delete("REDIS_URL") : ENV["REDIS_URL"] = previous_redis_url
    load Rails.root.join("config/initializers/sidekiq.rb")
  end

  test "sidekiq.yml parses concurrency and queues" do
    raw = Rails.root.join("config/sidekiq.yml").read
    config = YAML.safe_load(ERB.new(raw).result, permitted_classes: [ Symbol ])

    assert_kind_of Integer, config[:concurrency].to_i
    assert_operator config[:concurrency].to_i, :>, 0
    assert_equal %w[default mailers], config[:queues]
  end

  test "uses test queue adapter in test environment" do
    assert_equal "test", ActiveJob::Base.queue_adapter_name
  end
end
