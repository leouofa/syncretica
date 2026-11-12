# frozen_string_literal: true

module ApplicationHelper
  def render_markdown(text)
    return "" if text.blank?

    cleaned = text.to_s
      .gsub(%r{<think>.*?</think>}m, "")
      .strip

    html = Kramdown::Document.new(cleaned, input: "GFM", hard_wrap: false).to_html
    sanitize(html, tags: %w[
      h1 h2 h3 h4 h5 h6 p br hr ul ol li blockquote pre code em strong del a table thead tbody tr th td span div
    ], attributes: %w[href title class id target rel])
  end
end
