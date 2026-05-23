# frozen_string_literal: true

require "json"

module Ryfinance
  class TimezoneCache
    attr_reader :location

    def initialize(location = nil)
      @location = normalize_location(location)
    end

    def enabled?
      !@location.nil?
    end

    def get(symbol)
      data[normalize_symbol(symbol)]
    end

    def set(symbol, timezone)
      return timezone unless enabled?
      return timezone if timezone.nil? || timezone.to_s.empty?

      values = data
      values[normalize_symbol(symbol)] = timezone
      write(values)
      timezone
    end

    def to_h
      data.dup
    end

    private

    def data
      return {} unless enabled?
      return {} unless File.file?(file_path)

      JSON.parse(File.read(file_path))
    rescue JSON::ParserError
      {}
    end

    def write(values)
      mkdir_p(@location)
      File.write(file_path, JSON.pretty_generate(values))
    end

    def file_path
      File.join(@location, "tz_cache.json")
    end

    def normalize_location(location)
      return nil if location.nil?

      value = location.to_s.strip
      value.empty? ? nil : File.expand_path(value)
    end

    def normalize_symbol(symbol)
      symbol.to_s.strip.upcase
    end

    def mkdir_p(path)
      parts = File.expand_path(path).split(File::SEPARATOR)
      current = parts.first == "" ? File::SEPARATOR : parts.shift

      parts.each do |part|
        current = File.join(current, part)
        Dir.mkdir(current) unless Dir.exist?(current)
      end
    end
  end

  @timezone_cache = TimezoneCache.new

  class << self
    attr_reader :timezone_cache

    def tz_cache_location
      @timezone_cache.location
    end

    def set_tz_cache_location(path)
      @timezone_cache = TimezoneCache.new(path)
      @timezone_cache.location
    end
  end
end

