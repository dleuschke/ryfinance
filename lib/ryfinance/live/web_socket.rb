# frozen_string_literal: true

require "set"
require "json"

module Ryfinance
  class AsyncWebSocket
    DEFAULT_URL = "wss://streamer.finance.yahoo.com/?version=2"

    attr_reader :url, :subscriptions

    def initialize(url: DEFAULT_URL, verbose: true, transport: nil, heartbeat_interval: 15, reconnect: true, reconnect_delay: 3, raise_handler_errors: false)
      @url = url
      @verbose = verbose
      @transport = transport || Live::AsyncTransport.new
      @heartbeat_interval = heartbeat_interval
      @reconnect = reconnect
      @reconnect_delay = reconnect_delay
      @raise_handler_errors = raise_handler_errors
      @subscriptions = Set.new
      @connection = nil
      @connection_mutex = Mutex.new
      @closed = false
    end

    def subscribe(symbols)
      normalized = Live::Codec.normalize_symbols(symbols)
      @subscriptions.merge(normalized)
      write_control_message(subscribe: @subscriptions.to_a)
      self
    end

    def unsubscribe(symbols)
      normalized = Live::Codec.normalize_symbols(symbols)
      @subscriptions.subtract(normalized)
      write_control_message(unsubscribe: normalized)
      self
    end

    def listen(message_handler = nil, &block)
      handler = block || message_handler
      @closed = false

      loop do
        stream(handler)
        break unless @reconnect && !@closed

        sleep @reconnect_delay if @reconnect_delay.to_f.positive?
      end

      self
    end

    def close
      @closed = true
      begin
        connection&.close
      rescue StandardError => error
        announce("Error closing WebSocket: #{error.message}")
      end

      self
    end

    def closed?
      @closed
    end

    private

    def stream(handler)
      announce("Connected to WebSocket.")
      @transport.stream(
        url: @url,
        subscriptions: @subscriptions,
        heartbeat_interval: @heartbeat_interval,
        stop_if: -> { @closed },
        on_message: ->(frame) { handle_frame(frame, handler) },
        on_connection: ->(connection) { self.connection = connection }
      )
    rescue StandardError => error
      announce("WebSocket error: #{error.message}")
      raise if @raise_handler_errors || !@reconnect
    ensure
      announce("WebSocket connection closed.") if @closed
    end

    def handle_frame(frame, handler)
      message = Live::Codec.decode_frame(frame)
      if handler
        handler.call(message)
      else
        puts message
      end
    rescue StandardError => error
      announce("Error in message handler: #{error.message}")
      raise if @raise_handler_errors
    end

    def announce(message)
      puts message if @verbose
    end

    def connection
      @connection_mutex.synchronize { @connection }
    end

    def connection=(value)
      @connection_mutex.synchronize { @connection = value }
    end

    def write_control_message(payload)
      active_connection = connection
      return unless active_connection

      if @transport.respond_to?(:send_json)
        @transport.send_json(active_connection, payload)
      else
        active_connection.write(JSON.generate(payload))
        active_connection.flush if active_connection.respond_to?(:flush)
      end
    rescue StandardError => error
      announce("WebSocket control message failed: #{error.message}")
      raise if @raise_handler_errors
    end
  end

  class WebSocket < AsyncWebSocket
    def listen(message_handler = nil, &block)
      require "async"

      Async { super(message_handler, &block) }.wait
      self
    end
  end
end
