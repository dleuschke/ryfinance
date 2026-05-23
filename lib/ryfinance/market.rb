# frozen_string_literal: true

require "time"

module Ryfinance
  class Market
    VALID_MARKETS = %w[US GB ASIA EUROPE RATES COMMODITIES CURRENCIES CRYPTOCURRENCIES].freeze

    attr_reader :market, :region

    def initialize(market = nil, region: "US", session: nil, client: nil, timeout: 30)
      @market = (market || region).to_s.upcase
      @region = @market
      @client = client || session || Client.new
      @timeout = timeout
      @summary = nil
      @status = nil
    end

    def summary(timeout: nil)
      fetch_market_data(timeout: timeout || @timeout)
      @summary
    end

    def status(timeout: nil)
      fetch_market_data(timeout: timeout || @timeout)
      @status
    end

    private

    def fetch_market_data(timeout:)
      return if @summary && @status

      summary_rows = @client.market_summary(market: @market, timeout: timeout)
      status_row = @client.market_status(market: @market, timeout: timeout)

      @summary = summary_table(summary_rows)
      @status = status_hash(status_row)
    end

    def summary_table(rows)
      parsed_rows = Array(rows).map do |row|
        Utils.deep_symbolize(Utils.unwrap_value(row))
      end

      Table.new(parsed_rows, metadata: { market: @market })
    end

    def status_hash(row)
      status = Utils.deep_symbolize(Utils.unwrap_value(row || {}))
      timezone = status[:timezone]
      timezone = timezone.first if timezone.is_a?(Array)
      status[:timezone] = timezone if timezone
      status.delete(:time)
      status[:open] = parse_market_time(status[:open]) if status.key?(:open)
      status[:close] = parse_market_time(status[:close]) if status.key?(:close)
      status[:tz] = timezone[:short] if timezone.is_a?(Hash) && timezone[:short]
      status
    end

    def parse_market_time(value)
      return value if value.is_a?(Time)
      return Utils.yahoo_date(value) if value.is_a?(Integer)

      Time.iso8601(value.to_s)
    rescue ArgumentError
      value
    end
  end
end
