# frozen_string_literal: true

namespace :llm do
  desc "Verify RubyLLM configuration, database model registration, and live endpoint connectivity"
  task verify: :environment do
    api_base = RubyLLM.config.ollama_api_base
    model_id = RubyLLM.config.default_model

    abort "OLLAMA_API_BASE is not configured in RubyLLM.config.ollama_api_base" if api_base.blank?
    abort "OLLAMA_MODEL is not configured in RubyLLM.config.default_model" if model_id.blank?

    puts "Configured endpoint: #{api_base}"
    puts "Configured model:    #{model_id}"

    record = Llm::ModelRegistry.ensure_configured_model!(model_id: model_id)
    puts "Registered DB model: #{record.provider}/#{record.model_id} (id=#{record.id})"

    chat = RubyLLM.chat(model: model_id, provider: :ollama)
    response = chat.ask("Reply with only the word OK.")

    content = response.content.to_s.strip
    abort "Received empty response from #{api_base}" if content.empty?

    puts "Live response:       #{content}"
    puts "Verification passed!"
  end
end
