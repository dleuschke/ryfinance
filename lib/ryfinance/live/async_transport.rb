# frozen_string_literal: true

require "json"

module Ryfinance
  module Live
    class AsyncTransport
      def stream(url:, subscriptions:, heartbeat_interval:, stop_if:, on_message:, on_connection: nil)
        require "async"
        require "async/http/endpoint"
        require "async/websocket/client"
        require "protocol/websocket/message"

        endpoint = endpoint_for(url)

        Async::WebSocket::Client.connect(endpoint) do |connection|
          on_connection&.call(connection)
          send_json(connection, subscribe: subscriptions.to_a) unless subscriptions.empty?
          heartbeat = start_heartbeat(connection, subscriptions, heartbeat_interval)

          while !stop_if.call && (frame = connection.read)
            on_message.call(frame)
          end
        ensure
          heartbeat&.stop
          on_connection&.call(nil)
          connection&.close
        end
      end

      def send_json(connection, payload)
        require "protocol/websocket/message"

        connection.write(Protocol::WebSocket::TextMessage.generate(payload))
        connection.flush if connection.respond_to?(:flush)
      end

      private

      def endpoint_for(url)
        endpoint_url = url.to_s.sub(/\Awss:/, "https:").sub(/\Aws:/, "http:")
        Async::HTTP::Endpoint.parse(endpoint_url, alpn_protocols: Async::HTTP::Protocol::HTTP11.names)
      end

      def start_heartbeat(connection, subscriptions, heartbeat_interval)
        return nil if heartbeat_interval.nil? || heartbeat_interval.to_f <= 0

        Async::Task.current.async do
          loop do
            sleep heartbeat_interval
            send_json(connection, subscribe: subscriptions.to_a) unless subscriptions.empty?
          end
        end
      end
    end
  end
end
