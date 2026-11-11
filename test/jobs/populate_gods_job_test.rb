# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateGodsJobTest < ActiveSupport::TestCase
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

  test "perform iterates through pantheons, upserts gods with themes, and streams progress" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    norse = Pantheon.create!(name: "Norse", description: "Asgardian deities.")
    God.create!(pantheon: greek, name: "Zeus", description: "Initial Zeus description", themes: [ "sky" ])

    calls = []
    responses = {
      "Greek" => <<~TEXT,
        <think>Listing Greek gods.</think>
        ```json
        {
          "gods": [
            { "name": "Zeus", "description": "King of the Olympian gods.", "themes": ["sky", "thunder", "kingship"] },
            { "name": "Athena", "description": "Goddess of wisdom and strategy.", "themes": ["wisdom", "warfare"] }
          ]
        }
        ```
      TEXT
      "Norse" => {
        "gods" => [
          { "name" => "Odin", "description" => "Allfather of Asgard.", "themes" => [ "wisdom", "magic", "war" ] }
        ]
      }.to_json
    }

    with_stubbed_agent_create(->(pantheon_name:, pantheon_description:, existing_names:) {
      calls << { pantheon_name: pantheon_name, pantheon_description: pantheon_description, existing_names: existing_names }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(pantheon_name))
      end
      fake_chat
    }) do
      # 2 pantheons * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateGodsJob::STREAM_NAME, 6) do
        PopulateGodsJob.perform_now
      end
    end

    assert_equal [ "Greek", "Norse" ], calls.map { |c| c[:pantheon_name] }
    assert_equal [ "Zeus" ], calls.first[:existing_names]
    assert_equal [], calls.second[:existing_names]

    assert_equal 3, God.count
    zeus = greek.gods.find_by!(name: "Zeus")
    assert_equal "King of the Olympian gods.", zeus.description
    assert_equal [ "sky", "thunder", "kingship" ], zeus.themes

    odin = norse.gods.find_by!(name: "Odin")
    assert_equal [ "wisdom", "magic", "war" ], odin.themes
  end

  test "perform continues to remaining pantheons if one pantheon fails" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    norse = Pantheon.create!(name: "Norse", description: "Asgardian deities.")

    with_stubbed_agent_create(->(pantheon_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on Greek" if pantheon_name == "Greek"

        OpenStruct.new(
          parsed: nil,
          content: {
            "gods" => [
              { "name" => "Thor", "description" => "God of thunder.", "themes" => [ "thunder", "strength" ] }
            ]
          }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateGodsJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateGodsJob.perform_now }
      end
    end

    assert_equal 0, greek.gods.count
    assert_equal 1, norse.gods.count
    assert_equal "Thor", norse.gods.first.name
  end

  test "perform broadcasts error status and returns early when no pantheons exist" do
    assert_broadcasts(PopulateGodsJob::STREAM_NAME, 2) do
      assert_nothing_raised { PopulateGodsJob.perform_now }
    end

    assert_equal 0, God.count
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = GodDiscoveryAgent.singleton_class
    original = GodDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
