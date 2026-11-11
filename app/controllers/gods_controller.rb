# frozen_string_literal: true

class GodsController < ApplicationController
  def populate
    PopulateGodsJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "gods_populate_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "gods_populate_controls",
            action_path: populate_gods_path,
            idle_label: "Populate Gods",
            running_label: "Discovering Gods...",
            running: true,
            status_message: "Asking the agent to discover gods across pantheons...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to gods_path, notice: "Asking the agent to discover gods across pantheons..." }
    end
  end
end
