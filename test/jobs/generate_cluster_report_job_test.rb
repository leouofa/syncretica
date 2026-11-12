# frozen_string_literal: true

require "test_helper"
require "ostruct"

class GenerateClusterReportJobTest < ActiveSupport::TestCase
  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end

    @snapshot = ClusterSnapshot.create!(
      target_type: "God",
      level: 5,
      distance_threshold: 0.20,
      title: "Solar Pantheon",
      clusters_count: 0,
      items_count: 0
    )
    @report = @snapshot.cluster_reports.create!(prompt: "Find patterns across myths or gods")
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "performs report generation and marks completed" do
    fake_response = OpenStruct.new(
      content: "# Patterns in the Solar Realm\n\nExecutive Summary: Solar gods represent celestial sovereignty."
    )

    fake_chat = Object.new
    fake_chat.define_singleton_method(:ask) { |_prompt| fake_response }

    with_stubbed_agent_create(->(**) { fake_chat }) do
      GenerateClusterReportJob.perform_now(@report.id)
    end

    @report.reload
    assert @report.completed?
    assert_equal "Patterns in the Solar Realm", @report.title
    assert_includes @report.content, "Executive Summary"
    assert_not_nil @report.completed_at
  end

  test "handles error and marks failed" do
    fake_chat = Object.new
    fake_chat.define_singleton_method(:ask) { |_prompt| raise "Ollama connection refused" }

    with_stubbed_agent_create(->(**) { fake_chat }) do
      GenerateClusterReportJob.perform_now(@report.id)
    end

    @report.reload
    assert @report.failed?
    assert_includes @report.error_message, "Ollama connection refused"
  end

  private

  def with_stubbed_agent_create(callable)
    singleton = ClusterReportAgent.singleton_class
    original = ClusterReportAgent.method(:create!)
    singleton.define_method(:create!, &callable)
    yield
  ensure
    singleton.define_method(:create!, original)
  end
end
