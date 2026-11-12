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
      clusters_count: 1,
      items_count: 1
    )
    @group = @snapshot.cluster_groups.create!(name: "Solar Realm", shared_themes: [ "sun" ], size: 1)
    @report = @snapshot.cluster_reports.create!(prompt: "Find patterns across myths or gods")
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "performs report generation and marks completed" do
    fake_cluster_response = OpenStruct.new(
      content: "Cluster 1 represents sovereignty over celestial realms and civic law."
    )
    fake_report_response = OpenStruct.new(
      content: "# Patterns in the Solar Realm\n\nExecutive Summary: Solar gods represent celestial sovereignty."
    )

    fake_cluster_chat = Object.new
    fake_cluster_chat.define_singleton_method(:ask) { |_prompt| fake_cluster_response }

    fake_report_chat = Object.new
    fake_report_chat.define_singleton_method(:ask) { |_prompt| fake_report_response }

    with_stubbed_agent_creates(fake_cluster_chat, fake_report_chat) do
      GenerateClusterReportJob.perform_now(@report.id)
    end

    @report.reload
    assert @report.completed?
    assert_equal "completed", @report.phase
    assert_equal "Patterns in the Solar Realm", @report.title
    assert_includes @report.content, "Executive Summary"
    assert_not_nil @report.completed_at
  end

  test "handles error and marks failed" do
    fake_cluster_chat = Object.new
    fake_cluster_chat.define_singleton_method(:ask) { |_prompt| raise "Ollama connection refused" }

    fake_report_chat = Object.new

    with_stubbed_agent_creates(fake_cluster_chat, fake_report_chat) do
      GenerateClusterReportJob.perform_now(@report.id)
    end

    @report.reload
    assert @report.failed?
    assert_equal "failed", @report.phase
    assert_includes @report.error_message, "Ollama connection refused"
  end

  test "skips cluster group summary agent when summaries already exist for all clusters" do
    @report.update!(is_detailed: true, batch_size: 5)
    @report.cluster_report_summaries.create!(
      cluster_group: @group,
      position: 1,
      content: "Pre-existing cluster analysis"
    )

    fake_batch_response = OpenStruct.new(content: "Batch aggregated analysis")
    fake_batch_chat = Object.new
    fake_batch_chat.define_singleton_method(:ask) { |_prompt| fake_batch_response }

    fake_deep_response = OpenStruct.new(content: "# Deep Archetype Patterns\n\nDeep narrative.")
    fake_deep_chat = Object.new
    fake_deep_chat.define_singleton_method(:ask) { |_prompt| fake_deep_response }

    cluster_agent_called = false
    c_singleton = ClusterGroupSummaryAgent.singleton_class
    c_original = ClusterGroupSummaryAgent.method(:create!)
    c_singleton.define_method(:create!) do |**|
      cluster_agent_called = true
      flunk("ClusterGroupSummaryAgent should not be called when summaries already exist")
    end

    b_singleton = ClusterBatchSummaryAgent.singleton_class
    b_original = ClusterBatchSummaryAgent.method(:create!)
    b_singleton.define_method(:create!) { |**| fake_batch_chat }

    d_singleton = DeepSynthesisReportAgent.singleton_class
    d_original = DeepSynthesisReportAgent.method(:create!)
    d_singleton.define_method(:create!) { |**| fake_deep_chat }

    begin
      GenerateClusterReportJob.perform_now(@report.id)
    ensure
      c_singleton.define_method(:create!, c_original)
      b_singleton.define_method(:create!, b_original)
      d_singleton.define_method(:create!, d_original)
    end

    @report.reload
    assert_not cluster_agent_called
    assert @report.completed?
    assert_equal "Deep Archetype Patterns", @report.title
    assert_equal 1, @report.cluster_sub_reports.count
    assert_equal "Batch aggregated analysis", @report.cluster_sub_reports.first.content
  end

  private

  def with_stubbed_agent_creates(cluster_chat, report_chat)
    c_singleton = ClusterGroupSummaryAgent.singleton_class
    c_original = ClusterGroupSummaryAgent.method(:create!)
    c_singleton.define_method(:create!) { |**| cluster_chat }

    r_singleton = ClusterReportAgent.singleton_class
    r_original = ClusterReportAgent.method(:create!)
    r_singleton.define_method(:create!) { |**| report_chat }

    yield
  ensure
    c_singleton.define_method(:create!, c_original)
    r_singleton.define_method(:create!, r_original)
  end
end
