# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulatePantheonsJobTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "perform runs agent, upserts pantheons, and broadcasts Turbo Stream updates" do
    Pantheon.create!(name: "Greek", description: "Initial Greek description")

    fake_response = OpenStruct.new(
      parsed: {
        "pantheons" => [
          { "name" => "Greek", "description" => "Deities of Mount Olympus led by Zeus." },
          { "name" => "Egyptian", "description" => "Ancient Nile deities including Ra, Isis, and Osiris." }
        ]
      }
    )

    received_existing_names = nil
    fake_chat = Object.new
    fake_chat.define_singleton_method(:ask) { |_prompt| fake_response }

    with_stubbed_agent_create(->(existing_names:) {
      received_existing_names = existing_names
      fake_chat
    }) do
      assert_broadcasts(PopulatePantheonsJob::STREAM_NAME, 2) do
        PopulatePantheonsJob.perform_now
      end
    end

    assert_equal [ "Greek" ], received_existing_names
    assert_equal 2, Pantheon.count
    assert_equal "Deities of Mount Olympus led by Zeus.", Pantheon.find_by!(name: "Greek").description
    assert_equal "Ancient Nile deities including Ra, Isis, and Osiris.", Pantheon.find_by!(name: "Egyptian").description
  end

  test "perform broadcasts error status and recovers gracefully when LLM fails" do
    fake_chat = Object.new
    fake_chat.define_singleton_method(:ask) { |_prompt| raise "LLM connection refused" }

    with_stubbed_agent_create(->(**) { fake_chat }) do
      assert_broadcasts(PopulatePantheonsJob::STREAM_NAME, 2) do
        assert_nothing_raised { PopulatePantheonsJob.perform_now }
      end
    end
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = PantheonDiscoveryAgent.singleton_class
    original = PantheonDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
