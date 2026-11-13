# frozen_string_literal: true

module Api
  class JobStatusTracker
    KEY_PREFIX = "api:job_status:"
    RECENT_JOBS_KEY = "api:recent_jobs"
    MAX_RECENT_JOBS = 50
    TTL = 24.hours

    STATUS_QUEUED    = "queued"
    STATUS_RUNNING   = "running"
    STATUS_COMPLETED = "completed"
    STATUS_FAILED    = "failed"

    class << self
      def cache_store
        @cache_store ||= begin
          if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
            ActiveSupport::Cache::MemoryStore.new
          else
            Rails.cache
          end
        end
      end
      def record_enqueued(job_id, job_class:, arguments: [])
        return if job_id.blank?

        data = {
          job_id: job_id.to_s,
          job_class: job_class.to_s,
          arguments: serialize_args(arguments),
          status: STATUS_QUEUED,
          progress: nil,
          message: "Job queued for execution",
          result: nil,
          error: nil,
          enqueued_at: Time.current.iso8601,
          started_at: nil,
          completed_at: nil,
          updated_at: Time.current.iso8601
        }

        save(job_id, data)
        append_recent(job_id)
        data
      end

      def record_started(job_id, message: "Job is running")
        return if job_id.blank?

        update(job_id) do |data|
          data[:status] = STATUS_RUNNING
          data[:message] = message
          data[:started_at] ||= Time.current.iso8601
          data[:updated_at] = Time.current.iso8601
        end
      end

      def record_progress(job_id, message:, progress: nil, result: nil)
        return if job_id.blank?

        update(job_id) do |data|
          data[:status] = STATUS_RUNNING
          data[:message] = message
          data[:progress] = progress if progress.present?
          data[:result] = result if result.present?
          data[:started_at] ||= Time.current.iso8601
          data[:updated_at] = Time.current.iso8601
        end
      end

      def record_completed(job_id, message: "Job completed successfully", result: nil)
        return if job_id.blank?

        update(job_id) do |data|
          data[:status] = STATUS_COMPLETED
          data[:message] = message
          data[:result] = result if result.present?
          data[:completed_at] = Time.current.iso8601
          data[:updated_at] = Time.current.iso8601
        end
      end

      def record_failed(job_id, error:, message: nil)
        return if job_id.blank?

        error_message = error.respond_to?(:message) ? error.message : error.to_s
        update(job_id) do |data|
          data[:status] = STATUS_FAILED
          data[:message] = message || "Job failed: #{error_message}"
          data[:error] = error_message
          data[:completed_at] = Time.current.iso8601
          data[:updated_at] = Time.current.iso8601
        end
      end

      def get(job_id)
        return nil if job_id.blank?

        raw = cache_store.read("#{KEY_PREFIX}#{job_id}")
        raw.is_a?(Hash) ? raw.deep_symbolize_keys : nil
      end

      def recent_jobs(limit: 20)
        job_ids = Array(cache_store.read(RECENT_JOBS_KEY))
        job_ids.take(limit).filter_map { |id| get(id) }
      end

      private

      def save(job_id, data)
        cache_store.write("#{KEY_PREFIX}#{job_id}", data, expires_in: TTL)
      end

      def update(job_id)
        current = get(job_id) || {
          job_id: job_id.to_s,
          job_class: "UnknownJob",
          status: STATUS_RUNNING,
          enqueued_at: Time.current.iso8601
        }
        yield current
        save(job_id, current)
        current
      end

      def append_recent(job_id)
        job_ids = Array(cache_store.read(RECENT_JOBS_KEY))
        job_ids.delete(job_id.to_s)
        job_ids.unshift(job_id.to_s)
        job_ids = job_ids.take(MAX_RECENT_JOBS)
        cache_store.write(RECENT_JOBS_KEY, job_ids, expires_in: TTL)
      rescue StandardError
        # Graceful fallback if cache store fails on write
        nil
      end

      def serialize_args(args)
        Array(args).map do |arg|
          case arg
          when ActiveRecord::Base
            { class: arg.class.name, id: arg.id }
          when Hash
            arg.transform_values { |v| v.is_a?(ActiveRecord::Base) ? { class: v.class.name, id: v.id } : v }
          else
            arg
          end
        end
      rescue StandardError
        []
      end
    end
  end
end
