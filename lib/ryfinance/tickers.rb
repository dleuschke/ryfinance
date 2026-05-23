# frozen_string_literal: true

module Ryfinance
  class Tickers
    attr_reader :symbols, :tickers

    def initialize(tickers, session: nil, client: nil, proxy: nil)
      @symbols = Utils.normalize_tickers(tickers)
      @client = client || session || Client.new(proxy: proxy)
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

    def live(message_handler = nil, verbose: true, websocket: nil, **options, &block)
      handler = block || message_handler
      socket = websocket || WebSocket.new(verbose: verbose, **options)
      socket.subscribe(@symbols)
      return socket unless handler

      socket.listen(handler)
    end
  end
end
