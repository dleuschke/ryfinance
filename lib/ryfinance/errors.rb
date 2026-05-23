# frozen_string_literal: true

module Ryfinance
  class Error < StandardError; end

  class InvalidTickerError < Error; end
  class UnsupportedFeatureError < Error; end

  class HTTPError < Error
    attr_reader :status, :body, :uri

    def initialize(message, status:, body:, uri:)
      super(message)
      @status = status
      @body = body
      @uri = uri
    end
  end

  class RateLimitError < HTTPError; end

  class YahooError < Error
    attr_reader :code, :description

    def initialize(message, code: nil, description: nil)
      super(message)
      @code = code
      @description = description
    end
  end

  class NotFoundError < YahooError; end
end

