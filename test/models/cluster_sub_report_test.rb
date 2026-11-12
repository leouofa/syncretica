# frozen_string_literal: true

require "test_helper"

class ClusterSubReportTest < ActiveSupport::TestCase
  setup do
    @snapshot = ClusterSnapshot.create!(
      target_type: "God",
      level: 5,
      distance_threshold: 0.20,
      title: "Sub Report Snapshot",
      clusters_count: 2,
      items_count: 4
    )
    @report = @snapshot.cluster_reports.create!(prompt: "Find patterns", is_detailed: true, batch_size: 5)
  end

  test "validates required fields and uniqueness of batch index per report" do
    sub_report = ClusterSubReport.new
    assert_not sub_report.valid?

    sub_report.cluster_report = @report
    sub_report.batch_index = 1
    sub_report.content = "Batch one narrative"
    assert sub_report.valid?
    sub_report.save!

    duplicate = ClusterSubReport.new(cluster_report: @report, batch_index: 1, content: "Duplicate")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:batch_index], "has already been taken"
  end

  test "allows the same batch index on a different report" do
    @report.cluster_sub_reports.create!(batch_index: 1, content: "Report A batch")
    other = @snapshot.cluster_reports.create!(prompt: "Other", is_detailed: true, batch_size: 5)
    assert other.cluster_sub_reports.create(batch_index: 1, content: "Report B batch").persisted?
  end

  test "ordered scope returns batches by index" do
    @report.cluster_sub_reports.create!(batch_index: 2, content: "two")
    @report.cluster_sub_reports.create!(batch_index: 1, content: "one")
    assert_equal [ 1, 2 ], @report.cluster_sub_reports.ordered.pluck(:batch_index)
  end

  test "cascades deletion when cluster report is destroyed" do
    sub_report = @report.cluster_sub_reports.create!(batch_index: 1, content: "Batch")
    assert_difference("ClusterSubReport.count", -1) do
      @report.destroy
    end
    assert_nil ClusterSubReport.find_by(id: sub_report.id)
  end
end
