# frozen_string_literal: true

module Ryfinance
  class Market
    attr_reader :region

    def initialize(region: "US", session: nil, client: nil)
      @region = region
      @client = client || session || Client.new
    end

    def summary(timeout: 10)
      rows = @client.market_summary(region: @region, timeout: timeout).map do |row|
        Utils.deep_symbolize(Utils.unwrap_value(row))
      end

      Table.new(rows)
    end
  end
end
