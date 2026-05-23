# frozen_string_literal: true

require "google/protobuf"
require "google/protobuf/descriptor_pb"

module Ryfinance
  module Live
    module PricingDataSchema
      FIELDS = [
        [:id, :string, 1],
        [:price, :float, 2],
        [:time, :sint64, 3],
        [:currency, :string, 4],
        [:exchange, :string, 5],
        [:quote_type, :int32, 6],
        [:market_hours, :int32, 7],
        [:change_percent, :float, 8],
        [:day_volume, :sint64, 9],
        [:day_high, :float, 10],
        [:day_low, :float, 11],
        [:change, :float, 12],
        [:short_name, :string, 13],
        [:expire_date, :sint64, 14],
        [:open_price, :float, 15],
        [:previous_close, :float, 16],
        [:strike_price, :float, 17],
        [:underlying_symbol, :string, 18],
        [:open_interest, :sint64, 19],
        [:options_type, :sint64, 20],
        [:mini_option, :sint64, 21],
        [:last_size, :sint64, 22],
        [:bid, :float, 23],
        [:bid_size, :sint64, 24],
        [:ask, :float, 25],
        [:ask_size, :sint64, 26],
        [:price_hint, :sint64, 27],
        [:vol_24hr, :sint64, 28],
        [:vol_all_currencies, :sint64, 29],
        [:from_currency, :string, 30],
        [:last_market, :string, 31],
        [:circulating_supply, :double, 32],
        [:market_cap, :double, 33]
      ].freeze
      FIELD_NAMES = FIELDS.map(&:first).freeze

      TYPE_MAP = {
        double: Google::Protobuf::FieldDescriptorProto::Type::TYPE_DOUBLE,
        float: Google::Protobuf::FieldDescriptorProto::Type::TYPE_FLOAT,
        int32: Google::Protobuf::FieldDescriptorProto::Type::TYPE_INT32,
        sint64: Google::Protobuf::FieldDescriptorProto::Type::TYPE_SINT64,
        string: Google::Protobuf::FieldDescriptorProto::Type::TYPE_STRING
      }.freeze

      module_function

      def message_class
        @message_class ||= begin
          build_descriptor
          Google::Protobuf::DescriptorPool.generated_pool.lookup("ryfinance.live.PricingData").msgclass
        end
      end

      def build_descriptor
        descriptor = Google::Protobuf::DescriptorPool.generated_pool.lookup("ryfinance.live.PricingData")
        return descriptor if descriptor

        Google::Protobuf::DescriptorPool.generated_pool.add_serialized_file(
          Google::Protobuf::FileDescriptorProto.encode(file_descriptor)
        )
      end

      def file_descriptor
        Google::Protobuf::FileDescriptorProto.new(
          name: "ryfinance/live/pricing.proto",
          package: "ryfinance.live",
          syntax: "proto3",
          message_type: [
            Google::Protobuf::DescriptorProto.new(
              name: "PricingData",
              field: FIELDS.map { |name, type, number| field_descriptor(name, type, number) }
            )
          ]
        )
      end

      def field_descriptor(name, type, number)
        Google::Protobuf::FieldDescriptorProto.new(
          name: name.to_s,
          number: number,
          label: Google::Protobuf::FieldDescriptorProto::Label::LABEL_OPTIONAL,
          type: TYPE_MAP.fetch(type)
        )
      end
    end
  end
end
