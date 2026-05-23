# frozen_string_literal: true

require "timeout"
require_relative "test_helper"

class LiveSmokeTest < Minitest::Test
  DEFAULT_SYMBOL = "BTC-USD"
  DEFAULT_TIMEOUT = 20

  def test_yahoo_websocket_receives_live_quote
    skip "Set RYFINANCE_LIVE=1 to run live Yahoo WebSocket smoke tests." unless ENV["RYFINANCE_LIVE"] == "1"

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
end
