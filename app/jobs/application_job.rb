# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  after_enqueue do |job|
    Api::JobStatusTracker.record_enqueued(
      job.job_id,
      job_class: job.class.name,
      arguments: job.arguments
    )
  end

  around_perform do |job, block|
    Api::JobStatusTracker.record_started(job.job_id)
    begin
      result = block.call
      # If job didn't explicitly mark itself completed/failed, record standard completion
      current = Api::JobStatusTracker.get(job.job_id)
      if current && current[:status] == Api::JobStatusTracker::STATUS_RUNNING
        Api::JobStatusTracker.record_completed(job.job_id, result: result.is_a?(Hash) ? result : nil)
      end
      result
    rescue StandardError => e
      Api::JobStatusTracker.record_failed(job.job_id, error: e)
      raise e
    end
  end

  protected

  def track_progress(message:, progress: nil, result: nil)
    Api::JobStatusTracker.record_progress(
      job_id,
      message: message,
      progress: progress,
      result: result
    )
  end

  def track_completed(message: "Completed", result: nil)
    Api::JobStatusTracker.record_completed(
      job_id,
      message: message,
      result: result
    )
  end

  def track_failed(error:, message: nil)
    Api::JobStatusTracker.record_failed(
      job_id,
      error: error,
      message: message
    )
  end
end
