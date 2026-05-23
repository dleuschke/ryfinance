# frozen_string_literal: true

module Ryfinance
  class Search
    attr_reader :query, :result

    def initialize(query, quotes_count: 8, news_count: 8, lists_count: 0, timeout: 10, session: nil, client: nil)
      @query = query
      @quotes_count = quotes_count
      @news_count = news_count
      @lists_count = lists_count
      @timeout = timeout
      @client = client || session || Client.new
      @result = {}
    end

    def fetch
      @result = Utils.deep_symbolize(
        @client.search(
          @query,
          quotes_count: @quotes_count,
          news_count: @news_count,
          lists_count: @lists_count,
          timeout: @timeout
        )
      )
      self
    end

    def quotes
      @result.fetch(:quotes, [])
    end

    def news
      @result.fetch(:news, [])
    end

    def lists
      @result.fetch(:lists, [])
    end

    def to_h
      @result.dup
    end
  end
end

