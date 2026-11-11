# frozen_string_literal: true

class PagesController < ApplicationController
  def home
    @pantheons = Pantheon.ordered
  end
end
