# frozen_string_literal: true

require "test_helper"
require "ostruct"

class PopulateMythsJobTest < ActiveSupport::TestCase
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

  test "perform iterates through gods, upserts myths, and streams progress" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    norse = Pantheon.create!(name: "Norse", description: "Asgardian deities.")
    zeus = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.", themes: [ "sky", "thunder" ])
    thor = God.create!(pantheon: norse, name: "Thor", description: "God of thunder.", themes: [ "thunder" ])
    Myth.create!(god: zeus, themes: { "Old Theme" => "Initial theme description." })

    calls = []
    responses = {
      "Zeus" => <<~TEXT,
        <think>Synthesizing myths for Zeus.</think>
        ```json
        {
          "Breaking the Generational Curse": "Overthrowing Cronus to free his siblings.",
          "Justice and Civic Moral Law (Themis and Dike)": "Upholding hospitality and oaths."
        }
        ```
      TEXT
      "Thor" => {
        "Defense of Cosmos against Chaos" => "Wielding Mjolnir to protect Asgard and Midgard."
      }.to_json
    }

    with_stubbed_agent_create(->(god_name:, god_description:, god_themes:, pantheon_name:) {
      calls << { god_name: god_name, god_description: god_description, god_themes: god_themes, pantheon_name: pantheon_name }
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        OpenStruct.new(parsed: nil, content: responses.fetch(god_name))
      end
      fake_chat
    }) do
      # 2 gods * 2 broadcasts (progress) + 2 broadcasts (final) = 6
      assert_broadcasts(PopulateMythsJob::STREAM_NAME, 6) do
        PopulateMythsJob.perform_now
      end
    end

    assert_equal [ "Zeus", "Thor" ], calls.map { |c| c[:god_name] }
    assert_equal [ "Greek", "Norse" ], calls.map { |c| c[:pantheon_name] }

    assert_equal 2, Myth.count
    assert_equal(
      {
        "Breaking the Generational Curse" => "Overthrowing Cronus to free his siblings.",
        "Justice and Civic Moral Law (Themis and Dike)" => "Upholding hospitality and oaths."
      },
      zeus.reload.myth.themes
    )
    assert_equal(
      { "Defense of Cosmos against Chaos" => "Wielding Mjolnir to protect Asgard and Midgard." },
      thor.reload.myth.themes
    )
  end

  test "perform continues to remaining gods if one god fails" do
    greek = Pantheon.create!(name: "Greek", description: "Olympian deities.")
    norse = Pantheon.create!(name: "Norse", description: "Asgardian deities.")
    zeus = God.create!(pantheon: greek, name: "Zeus", description: "King of Olympus.")
    thor = God.create!(pantheon: norse, name: "Thor", description: "God of thunder.")

    with_stubbed_agent_create(->(god_name:, **) {
      fake_chat = Object.new
      fake_chat.define_singleton_method(:ask) do |_prompt|
        raise "Timeout on Zeus" if god_name == "Zeus"

        OpenStruct.new(
          parsed: nil,
          content: { "Storm and Protection" => "Defending Midgard with Mjolnir." }.to_json
        )
      end
      fake_chat
    }) do
      assert_broadcasts(PopulateMythsJob::STREAM_NAME, 6) do
        assert_nothing_raised { PopulateMythsJob.perform_now }
      end
    end

    assert_nil zeus.reload.myth
    assert_equal({ "Storm and Protection" => "Defending Midgard with Mjolnir." }, thor.reload.myth.themes)
  end

  test "perform broadcasts error status and returns early when no gods exist" do
    assert_broadcasts(PopulateMythsJob::STREAM_NAME, 2) do
      assert_nothing_raised { PopulateMythsJob.perform_now }
    end

    assert_equal 0, Myth.count
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = MythDiscoveryAgent.singleton_class
    original = MythDiscoveryAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
