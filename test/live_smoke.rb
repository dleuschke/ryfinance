# frozen_string_literal: true

require "timeout"
require_relative "test_helper"

class LiveSmokeTest < Minitest::Test
  DEFAULT_SYMBOL = "BTC-USD"
  DEFAULT_HTTP_SYMBOL = "MSFT"
  DEFAULT_TIMEOUT = 20

  def test_yahoo_websocket_receives_live_quote
    skip_unless_live!

    symbol = ENV.fetch("RYFINANCE_LIVE_SYMBOL", DEFAULT_SYMBOL)
    timeout_seconds = Integer(ENV.fetch("RYFINANCE_LIVE_TIMEOUT", DEFAULT_TIMEOUT.to_s))
    socket = Ryfinance::WebSocket.new(
      verbose: false,
      reconnect: false,
      heartbeat_interval: 5
    )
    quote = nil

    socket.subscribe(symbol)
    Timeout.timeout(timeout_seconds) do
      socket.listen do |message|
        flunk "Yahoo live stream returned decode error: #{message[:error]}" if message[:error]

        quote = message
        socket.close
      end
    end

    refute_nil quote, "Expected a quote for #{symbol} from Yahoo live stream."
    assert_equal symbol.upcase, quote[:id]
    assert_kind_of Numeric, quote[:price]
    assert_operator quote[:price], :>, 0
  rescue Timeout::Error
    flunk "No Yahoo live quote received for #{symbol} within #{timeout_seconds} seconds."
  ensure
    socket&.close
  end

  def test_yahoo_http_endpoints_return_core_data
    skip_unless_live!

    symbol = ENV.fetch("RYFINANCE_LIVE_HTTP_SYMBOL", DEFAULT_HTTP_SYMBOL)
    timeout_seconds = Integer(ENV.fetch("RYFINANCE_LIVE_TIMEOUT", DEFAULT_TIMEOUT.to_s))
    ticker = Ryfinance::Ticker.new(symbol)

    history = ticker.history(period: "5d", raise_errors: true, timeout: timeout_seconds)
    refute_empty history, "Expected recent Yahoo chart data for #{symbol}."
    assert_kind_of Numeric, history.last[:close]
    assert_operator history.last[:close], :>, 0

    fast_info = ticker.fast_info(timeout: timeout_seconds)
    assert_equal symbol.upcase, fast_info[:symbol]
    assert_kind_of Numeric, fast_info[:last_price]
    assert_operator fast_info[:last_price], :>, 0

    search = Ryfinance.search(symbol, quotes_count: 1, news_count: 0, client: Ryfinance::Client.new, timeout: timeout_seconds)
    assert search.quotes.any? { |quote| quote[:symbol].to_s.casecmp(symbol).zero? },
           "Expected Yahoo search to return #{symbol}."
  end

  private

  def skip_unless_live!
    skip "Set RYFINANCE_LIVE=1 to run live Yahoo smoke tests." unless ENV["RYFINANCE_LIVE"] == "1"
  end
end
