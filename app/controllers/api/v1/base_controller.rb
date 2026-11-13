# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
      rescue_from ArgumentError, with: :render_argument_error

      private

      def render_success(data, meta: nil, status: :ok)
        payload = { data: data }
        payload[:meta] = meta if meta.present?
        render json: payload, status: status
      end

      def render_error(code:, message:, details: nil, status: :bad_request)
        error_obj = { code: code, message: message }
        error_obj[:details] = details if details.present?
        render json: { error: error_obj }, status: status
      end

      def render_not_found(exception)
        render_error(
          code: "not_found",
          message: exception.message,
          status: :not_found
        )
      end

      def render_record_invalid(exception)
        render_error(
          code: "validation_error",
          message: exception.message,
          details: exception.record.errors.full_messages,
          status: :unprocessable_entity
        )
      end

      def render_parameter_missing(exception)
        render_error(
          code: "parameter_missing",
          message: exception.message,
          status: :bad_request
        )
      end

      def render_argument_error(exception)
        render_error(
          code: "argument_error",
          message: exception.message,
          status: :bad_request
        )
      end

      def paginate(scope, default_limit: 50, max_limit: 500)
        total = scope.count
        limit = (params[:limit].presence || default_limit).to_i.clamp(1, max_limit)
        offset = [ params[:offset].to_i, 0 ].max
        records = scope.limit(limit).offset(offset)
        [ records, { total: total, limit: limit, offset: offset } ]
      end

      def boolean_param(key, default: false)
        return default unless params.key?(key)

        ActiveModel::Type::Boolean.new.cast(params[key])
      end

      def sync_requested?
        boolean_param(:sync, default: false)
      end
    end
  end
end
