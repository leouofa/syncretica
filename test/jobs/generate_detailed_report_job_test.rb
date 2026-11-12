# frozen_string_literal: true

require "test_helper"
require "ostruct"

class GenerateDetailedReportJobTest < ActiveSupport::TestCase
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
      title: "Detailed Snapshot",
      clusters_count: 5,
      items_count: 5
    )
    @groups = 5.times.map do |i|
      @snapshot.cluster_groups.create!(name: "Cluster Group #{i + 1}", shared_themes: [ "theme#{i + 1}" ], size: 1)
    end
    @report = @snapshot.cluster_reports.create!(
      prompt: "Find patterns across myths or gods",
      is_detailed: true,
      batch_size: 2
    )
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "performs three-phase detailed synthesis and marks completed" do
    cluster_chat = fake_chat("Cluster level analysis of cross-pantheon parallels.")
    batch_chat = fake_chat("Batch narrative preserving Cluster #1 and Cluster #2 specifics.")
    synthesis_chat = fake_chat("# Deep Report\n\nExecutive Summary: A richer synthesis across all batches.")

    with_stubbed_agent_creates(cluster_chat: cluster_chat, batch_chat: batch_chat, synthesis_chat: synthesis_chat) do
      GenerateClusterReportJob.perform_now(@report.id)
    end

    @report.reload
    assert @report.completed?
    assert_equal "completed", @report.phase
    assert_equal "Deep Report", @report.title
    assert_includes @report.content, "Executive Summary"
    assert_not_nil @report.completed_at

    # Phase 1: every cluster summarized
    assert_equal 5, @report.cluster_report_summaries.count

    # Phase 2: 5 clusters / batch size 2 => 3 batches
    assert_equal 3, @report.total_batches_count
    assert_equal 3, @report.aggregated_batches_count
    sub_reports = @report.cluster_sub_reports.ordered
    assert_equal [ 1, 2, 3 ], sub_reports.pluck(:batch_index)
    assert_equal [ 2, 2, 1 ], sub_reports.map { |sr| sr.cluster_group_ids.size }
  end

  test "resumes without duplicating existing summaries or batches" do
    first_group = @groups.first
    @report.cluster_report_summaries.create!(
      cluster_group: first_group,
      position: 1,
      content: "Pre-existing cluster analysis."
    )
    @report.cluster_sub_reports.create!(
      batch_index: 1,
      cluster_group_ids: @groups.first(2).map(&:id),
      content: "Pre-existing batch narrative."
    )

    cluster_chat = fake_chat("Cluster analysis")
    batch_chat = fake_chat("Batch narrative")
    synthesis_chat = fake_chat("# Deep Report\n\nExecutive Summary: Resumed.")

    with_stubbed_agent_creates(cluster_chat: cluster_chat, batch_chat: batch_chat, synthesis_chat: synthesis_chat) do
      GenerateClusterReportJob.perform_now(@report.id)
    end

    @report.reload
    assert @report.completed?
    assert_equal 5, @report.cluster_report_summaries.count
    assert_equal 3, @report.cluster_sub_reports.count
    assert_equal "Pre-existing batch narrative.", @report.cluster_sub_reports.find_by(batch_index: 1).content
  end

  test "handles aggregation error and marks failed" do
    cluster_chat = fake_chat("Cluster analysis")
    batch_chat = Object.new
    batch_chat.define_singleton_method(:ask) { |_prompt| raise "Ollama connection refused" }
    synthesis_chat = fake_chat("# Deep Report")

    with_stubbed_agent_creates(cluster_chat: cluster_chat, batch_chat: batch_chat, synthesis_chat: synthesis_chat) do
      GenerateClusterReportJob.perform_now(@report.id)
    end

    @report.reload
    assert @report.failed?
    assert_equal "failed", @report.phase
    assert_includes @report.error_message, "Ollama connection refused"
  end

  private

  def fake_chat(content)
    response = OpenStruct.new(content: content)
    chat = Object.new
    chat.define_singleton_method(:ask) { |_prompt| response }
    chat
  end

  def with_stubbed_agent_creates(cluster_chat:, batch_chat:, synthesis_chat:)
    stubs = {
      ClusterGroupSummaryAgent => cluster_chat,
      ClusterBatchSummaryAgent => batch_chat,
      DeepSynthesisReportAgent => synthesis_chat
    }
    originals = {}
    stubs.each do |agent, chat|
      originals[agent] = agent.method(:create!)
      agent.singleton_class.define_method(:create!) { |**| chat }
    end
    yield
  ensure
    originals.each { |agent, original| agent.singleton_class.define_method(:create!, original) }
  end
end
