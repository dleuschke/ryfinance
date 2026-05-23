# frozen_string_literal: true

module Ryfinance
  class Tickers
    attr_reader :symbols, :tickers

    def initialize(tickers, session: nil, client: nil)
      @symbols = Utils.normalize_tickers(tickers)
      @client = client || session || Client.new
      @tickers = @symbols.each_with_object({}) do |symbol, result|
        result[symbol] = Ticker.new(symbol, client: @client)
      end
    end

    def [](ticker)
      @tickers[ticker.to_s.upcase]
    end

    def history(**options)
      tables = @tickers.transform_values { |ticker| ticker.history(**options) }
      DownloadResult.new(tables, group_by: options.fetch(:group_by, "ticker"))
    end

    def download(**options)
      Ryfinance.download(@symbols, client: @client, **options)
    end

    def live(*)
      raise UnsupportedFeatureError, "WebSocket streaming is not implemented yet"
    end
  end
end
