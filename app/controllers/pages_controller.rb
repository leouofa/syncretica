# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    @pantheons = Pantheon.ordered
  end

  def gods
    @pantheon_groups = God.grouped_by_pantheon
    @total_gods_count = God.count
    @pantheons_count = Pantheon.count
  end
end
