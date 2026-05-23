# frozen_string_literal: true

require "csv"

module Ryfinance
  class Table
    include Enumerable

    attr_reader :rows, :columns, :metadata

    def initialize(rows = [], columns: nil, metadata: {})
      @rows = rows.map { |row| Utils.symbolize_keys(row) }
      @columns = (columns || infer_columns(@rows)).map { |column| Utils.symbolize_key(column) }
      @metadata = metadata
    end

    def each(&block)
      @rows.each(&block)
    end

    def [](key)
      return @rows[key] if key.is_a?(Integer)

      column(key)
    end

    def first(count = nil)
      return @rows.first if count.nil?

      self.class.new(@rows.first(count), columns: @columns, metadata: @metadata)
    end

    def last(count = nil)
      return @rows.last if count.nil?

      self.class.new(@rows.last(count), columns: @columns, metadata: @metadata)
    end

    def empty?
      @rows.empty?
    end

    def size
      @rows.size
    end
    alias length size

    def column(name)
      key = Utils.symbolize_key(name)
      @rows.map { |row| row[key] }
    end

    def where(&block)
      self.class.new(@rows.select(&block), columns: @columns, metadata: @metadata)
    end

    def to_a
      @rows.map(&:dup)
    end

    def to_h(index: :date)
      key = Utils.symbolize_key(index)

      return to_a unless @rows.all? { |row| row.key?(key) }

      @rows.each_with_object({}) do |row, result|
        result[row[key]] = row.reject { |column, _value| column == key }
      end
    end

    def to_csv
      CSV.generate(headers: true) do |csv|
        csv << @columns
        @rows.each do |row|
          csv << @columns.map { |column| row[column] }
        end
      end
    end

    def inspect
      "#<#{self.class.name} rows=#{size} columns=#{@columns.inspect}>"
    end

    private

    def infer_columns(rows)
      rows.flat_map(&:keys).uniq
    end
  end

  class DownloadResult
    include Enumerable

    attr_reader :tables, :group_by, :errors

    def initialize(tables, group_by: "column", errors: {})
      @tables = tables.transform_keys { |ticker| ticker.to_s.upcase }
      @group_by = group_by.to_s
      @errors = errors.transform_keys { |ticker| ticker.to_s.upcase }
    end

    def [](ticker)
      @tables[ticker.to_s.upcase]
    end

    def each(&block)
      @tables.each(&block)
    end

    def tickers
      @tables.keys
    end

    def failed_tickers
      @errors.keys
    end

    def successful_tickers
      tickers - failed_tickers
    end

    def success?
      @errors.empty?
    end

    def empty?
      @tables.empty? || @tables.values.all?(&:empty?)
    end

    def to_h
      @tables.transform_values(&:to_a)
    end

    def to_a
      return to_h if @group_by == "ticker"

      rows_by_date = {}

      @tables.each do |ticker, table|
        table.each do |row|
          date = row[:date] || row[:datetime]
          next if date.nil?

          output = (rows_by_date[date] ||= { date: date })
          row.each do |column, value|
            next if %i[date datetime].include?(column)

            output[:"#{ticker}.#{column}"] = value
          end
        end
      end

      rows_by_date.keys.sort.map { |date| rows_by_date[date] }
    end

    def inspect
      "#<#{self.class.name} tickers=#{tickers.inspect} group_by=#{@group_by.inspect}>"
    end
  end
end
