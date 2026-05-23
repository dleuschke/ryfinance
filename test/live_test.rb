# frozen_string_literal: true

require_relative "test_helper"

class FakeLiveTransport
  attr_reader :calls, :connections

  def initialize(frames = [])
    @frames = frames
    @calls = []
    @connections = []
  end

  def stream(url:, subscriptions:, heartbeat_interval:, stop_if:, on_message:, on_connection: nil)
    @calls << {
      url: url,
      subscriptions: subscriptions.to_a,
      heartbeat_interval: heartbeat_interval
    }

    connection = FakeLiveConnection.new
    @connections << connection
    on_connection&.call(connection)
    @frames.each do |frame|
      break if stop_if.call

      on_message.call(frame)
    end
  ensure
    on_connection&.call(nil)
  end
end

class FakeLiveConnection
  attr_reader :closed, :messages

  def initialize
    @messages = []
  end

  def write(message)
    @messages << message
  end

  def flush
    @flushed = true
  end

  def flushed?
    @flushed
  end

  def close
    @closed = true
  end
end

class LiveTest < Minitest::Test
  def test_codec_encodes_subscription_messages
    assert_equal({ "subscribe" => ["MSFT", "AAPL"] }, JSON.parse(Ryfinance::Live::Codec.encode_subscribe("msft aapl")))
    assert_equal({ "unsubscribe" => ["MSFT"] }, JSON.parse(Ryfinance::Live::Codec.encode_unsubscribe(["msft"])))
  end

  def test_codec_decodes_yahoo_pricing_frame
    frame = pricing_frame(id: "MSFT", price: 420.25, time: 1_704_067_200, day_volume: 123_456)

    message = Ryfinance::Live::Codec.decode_frame(frame)

    assert_equal "MSFT", message[:id]
    assert_in_delta 420.25, message[:price], 0.001
    assert_equal 1_704_067_200, message[:time]
    assert_equal 123_456, message[:day_volume]
  end

  def test_codec_returns_error_for_invalid_message
    message = Ryfinance::Live::Codec.decode_frame(JSON.generate(message: "not-protobuf"))

    assert message[:error]
    assert_equal "not-protobuf", message[:raw_base64]
  end

  def test_async_websocket_listens_with_fake_transport
    transport = FakeLiveTransport.new([pricing_frame(id: "AAPL", price: 191.12)])
    websocket = Ryfinance::AsyncWebSocket.new(transport: transport, verbose: false, reconnect: false)
    received = []

    websocket.subscribe(["aapl", "msft"])
    websocket.unsubscribe("msft")
    websocket.listen { |message| received << message }

    assert_equal ["AAPL"], transport.calls.first[:subscriptions]
    assert_equal "AAPL", received.first[:id]
    assert_in_delta 191.12, received.first[:price], 0.001
  end

  def test_websocket_sync_wrapper_uses_transport
    transport = FakeLiveTransport.new([pricing_frame(id: "MSFT", price: 420.25)])
    websocket = Ryfinance::WebSocket.new(transport: transport, verbose: false, reconnect: false)
    received = []

    websocket.subscribe("msft")
    websocket.listen { |message| received << message }

    assert_equal ["MSFT"], transport.calls.first[:subscriptions]
    assert_equal "MSFT", received.first[:id]
  end

  def test_close_closes_active_connection
    transport = FakeLiveTransport.new([pricing_frame(id: "MSFT", price: 420.25)])
    websocket = Ryfinance::AsyncWebSocket.new(transport: transport, verbose: false, reconnect: false)

    websocket.subscribe("msft")
    websocket.listen { |_message| websocket.close }

    assert transport.connections.first.closed
  end

  def test_subscribe_and_unsubscribe_send_on_active_connection
    transport = FakeLiveTransport.new([pricing_frame(id: "MSFT", price: 420.25)])
    websocket = Ryfinance::AsyncWebSocket.new(transport: transport, verbose: false, reconnect: false)

    websocket.subscribe("msft")
    websocket.listen do |_message|
      websocket.subscribe("aapl")
      websocket.unsubscribe("msft")
      websocket.close
    end

    messages = transport.connections.first.messages
    assert_equal JSON.generate("subscribe" => ["MSFT", "AAPL"]), messages[0]
    assert_equal JSON.generate("unsubscribe" => ["MSFT"]), messages[1]
  end

  def test_async_transport_writes_json_object_messages
    connection = FakeLiveConnection.new
    Ryfinance::Live::AsyncTransport.new.send_json(connection, subscribe: ["MSFT"])

    assert_equal JSON.generate("subscribe" => ["MSFT"]), connection.messages.first.buffer
    assert connection.flushed?
  end

  def test_ticker_live_returns_configured_socket_without_handler
    socket = Ryfinance::Ticker.new("msft").live(verbose: false, reconnect: false)

    assert_instance_of Ryfinance::WebSocket, socket
    assert_equal ["MSFT"], socket.subscriptions.to_a
  end

  def test_tickers_live_returns_configured_socket_without_handler
    socket = Ryfinance::Tickers.new("msft aapl").live(verbose: false, reconnect: false)

    assert_equal ["MSFT", "AAPL"], socket.subscriptions.to_a
  end

  def test_top_level_websocket_constructors
    assert_instance_of Ryfinance::WebSocket, Ryfinance.WebSocket(verbose: false, reconnect: false)
    assert_instance_of Ryfinance::AsyncWebSocket, Ryfinance.AsyncWebSocket(verbose: false, reconnect: false)
  end

  private

  def pricing_frame(**fields)
    klass = Ryfinance::Live::PricingDataSchema.message_class
    message = klass.new(**fields)
    JSON.generate("message" => [klass.encode(message)].pack("m0"))
  end
end
