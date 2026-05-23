# frozen_string_literal: true

require "date"
require "time"

module Ryfinance
  module Utils
    module_function

    def normalize_tickers(tickers)
      values =
        case tickers
        when String
          tickers.split(/[,\s]+/)
        else
          Array(tickers)
        end

      values.filter_map do |ticker|
        text = ticker.to_s.strip
        next if text.empty?

        text.upcase
      end.uniq
    end

    def underscore(value)
      value.to_s
           .gsub("::", "/")
           .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .tr("-", "_")
           .downcase
    end

    def symbolize_key(key)
      underscore(key).to_sym
    end

    def symbolize_keys(hash)
      hash.each_with_object({}) do |(key, value), result|
        result[symbolize_key(key)] = value
      end
    end

    def unwrap_value(value)
      case value
      when Hash
        if value.key?("raw")
          value["raw"]
        elsif value.key?(:raw)
          value[:raw]
        elsif value.key?("fmt") && value.length == 1
          value["fmt"]
        elsif value.key?(:fmt) && value.length == 1
          value[:fmt]
        else
          value.each_with_object({}) do |(key, nested), result|
            result[key] = unwrap_value(nested)
          end
        end
      when Array
        value.map { |entry| unwrap_value(entry) }
      else
        value
      end
    end

    def deep_symbolize(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), result|
          result[symbolize_key(key)] = deep_symbolize(nested)
        end
      when Array
        value.map { |entry| deep_symbolize(entry) }
      else
        value
      end
    end

    def to_timestamp(value)
      case value
      when nil
        nil
      when Integer
        value
      when Time
        value.to_i
      when DateTime
        value.to_time.to_i
      when Date
        value.to_time.to_i
      else
        text = value.to_s
        if text.match?(/\A\d+\z/)
          text.to_i
        elsif text.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          date = Date.iso8601(text)
          Time.utc(date.year, date.month, date.day).to_i
        else
          Time.parse(text).to_i
        end
      end
    end

    def maybe_round(value, places: 2)
      value.is_a?(Float) ? value.round(places) : value
    end

    def compact_nil(hash)
      hash.reject { |_key, value| value.nil? }
    end

    def yahoo_date(timestamp)
      Time.at(timestamp).utc
    end

    def expiration_date(timestamp)
      Time.at(timestamp).utc.strftime("%Y-%m-%d")
    end
  end
end
