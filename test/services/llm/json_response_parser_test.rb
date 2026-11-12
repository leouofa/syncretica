# frozen_string_literal: true

require "test_helper"
require "ostruct"

class Llm::JsonResponseParserTest < ActiveSupport::TestCase
  test "extract_list prefers response.parsed when present" do
    response = OpenStruct.new(parsed: { "gods" => [ { "name" => "Zeus" } ] }, content: "ignored")
    assert_equal [ { "name" => "Zeus" } ], Llm::JsonResponseParser.extract_list(response, key: "gods")
  end

  test "extract_list strips think tags and markdown fences" do
    response = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Thinking about deities...</think>
        ```json
        { "gods": [{ "name": "Athena", "themes": ["wisdom"] }] }
        ```
      TEXT
    )

    assert_equal [ { "name" => "Athena", "themes" => [ "wisdom" ] } ],
                 Llm::JsonResponseParser.extract_list(response, key: "gods")
  end

  test "extract_list falls back to embedded JSON and returns empty array for invalid text" do
    embedded_array = OpenStruct.new(parsed: nil, content: "Here is the list: [{\"name\":\"Ra\"}] Hope that helps!")
    assert_equal [ { "name" => "Ra" } ], Llm::JsonResponseParser.extract_list(embedded_array, key: "gods")

    embedded_object = OpenStruct.new(parsed: nil, content: "[Note] {\"gods\":[{\"name\":\"Isis\"}]} Done.")
    assert_equal [ { "name" => "Isis" } ], Llm::JsonResponseParser.extract_list(embedded_object, key: "gods")

    invalid = OpenStruct.new(parsed: nil, content: "Not JSON at all")
    assert_equal [], Llm::JsonResponseParser.extract_list(invalid, key: "gods")
  end

  test "extract_hash parses flat JSON objects and unwraps optional nested key" do
    flat = OpenStruct.new(
      parsed: nil,
      content: <<~TEXT
        <think>Analyzing Zeus themes...</think>
        ```json
        {
          "Cosmic Order vs. Primordial Chaos": "Establishing celestial rule.",
          "Submission to Fate (Moira)": "Navigating universal cosmic law."
        }
        ```
      TEXT
    )

    assert_equal(
      {
        "Cosmic Order vs. Primordial Chaos" => "Establishing celestial rule.",
        "Submission to Fate (Moira)" => "Navigating universal cosmic law."
      },
      Llm::JsonResponseParser.extract_hash(flat, key: "themes")
    )

    wrapped = OpenStruct.new(
      parsed: { "themes" => { "Sovereignty" => "Ruler of Olympus." } },
      content: "ignored"
    )
    assert_equal({ "Sovereignty" => "Ruler of Olympus." }, Llm::JsonResponseParser.extract_hash(wrapped, key: "themes"))

    invalid = OpenStruct.new(parsed: nil, content: "No JSON object here")
    assert_equal({}, Llm::JsonResponseParser.extract_hash(invalid, key: "themes"))
  end
end
