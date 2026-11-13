# frozen_string_literal: true

module Api
  module V1
    class OpenapiController < BaseController
      def show
        render json: OpenapiSpec.generate
      end
    end
  end
end
