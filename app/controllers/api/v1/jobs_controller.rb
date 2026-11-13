# frozen_string_literal: true

module Api
  module V1
    class JobsController < BaseController
      def index
        limit = (params[:limit].presence || 20).to_i.clamp(1, 50)
        jobs = JobStatusTracker.recent_jobs(limit: limit)
        render_success(jobs, meta: { count: jobs.size })
      end

      def show
        job = JobStatusTracker.get(params[:id])
        return render_error(code: "job_not_found", message: "Job with ID '#{params[:id]}' not found or expired", status: :not_found) unless job

        render_success(job)
      end
    end
  end
end
