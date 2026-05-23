# frozen_string_literal: true

require "base64"
require "json"

module Ryfinance
  module Live
    class Codec
      class << self
        def encode_subscribe(symbols)
          JSON.generate(subscribe: normalize_symbols(symbols))
        end

        def encode_unsubscribe(symbols)
          JSON.generate(unsubscribe: normalize_symbols(symbols))
        end

        def decode_frame(frame)
          payload = parse_frame(frame)
          encoded = payload.fetch("message", payload.fetch(:message, payload.to_s))
          decode_message(encoded)
        end

        def decode_message(base64_message)
          decoded_bytes = Base64.decode64(base64_message.to_s)
          message = PricingDataSchema.message_class.decode(decoded_bytes)
          protobuf_to_hash(message)
        rescue StandardError => error
          { error: error.message, raw_base64: base64_message }
        end

        def normalize_symbols(symbols)
          Utils.normalize_tickers(symbols)
        end

        private

        def parse_frame(frame)
          text =
            if frame.respond_to?(:data)
              frame.data
            elsif frame.respond_to?(:buffer)
              frame.buffer
            elsif frame.respond_to?(:to_str)
              frame.to_str
            else
              frame.to_s
            end

          JSON.parse(text)
        rescue JSON::ParserError
          { "message" => text }
        end

        def protobuf_to_hash(message)
          PricingDataSchema::FIELD_NAMES.each_with_object({}) do |field, result|
            value = message.public_send(field)
            next if default_value?(value)

            result[field] = value
          end
        end

        def default_value?(value)
          value.nil? || value == "" || value == 0 || value == 0.0 || value == false
        end
      end
    end
  end
end

