RubyLLM.configure do |config|
  config.ollama_api_base = ENV["OLLAMA_API_BASE"] if ENV["OLLAMA_API_BASE"].present?
  config.ollama_api_key = ENV["OLLAMA_API_KEY"] if ENV["OLLAMA_API_KEY"].present?
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", Rails.application.credentials.dig(:openai_api_key))

  config.default_model = ENV["OLLAMA_MODEL"] if ENV["OLLAMA_MODEL"].present?
  config.context_budget = { per_result: 0.25, per_request: 0.7 }
end
