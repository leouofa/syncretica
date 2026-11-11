# frozen_string_literal: true

class PantheonsController < ApplicationController
  def populate
    PopulatePantheonsJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "populate_controls",
          partial: "pages/populate_controls",
          locals: {
            running: true,
            status_message: "Asking the agent to discover pantheons...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to root_path, notice: "Asking the agent to discover pantheons..." }
    end
  end
end
