# frozen_string_literal: true

class MythsController < ApplicationController
  include EmbeddableActions

  def show
    @myth = Myth.includes(god: :pantheon).find(params[:id])
  end

  def generate_embedding
    @myth = Myth.find(params[:id])
    enqueue_embedding_generation(@myth)
  end

  def populate
    PopulateMythsJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "myths_populate_controls",
          partial: "pages/populate_controls",
          locals: {
            target_id: "myths_populate_controls",
            action_path: populate_myths_path,
            idle_label: "Populate Myths",
            running_label: "Discovering Myths...",
            running: true,
            status_message: "Asking the agent to discover mythical themes across gods...",
            status_kind: :info
          }
        )
      end
      format.html { redirect_to myths_path, notice: "Asking the agent to discover mythical themes across gods..." }
    end
  end
end
