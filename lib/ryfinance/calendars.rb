# frozen_string_literal: true

require "date"
require "time"

module Ryfinance
  class CalendarQuery
    attr_reader :operator, :operands

    def initialize(operator, operands)
      @operator = operator.to_s.tr("_", "-").upcase
      @operands = Array(operands)
    end

    def append(operand)
      @operands << operand
      self
    end

    def empty?
      @operands.empty?
    end

    def to_h
      {
        "operator" => @operator,
        "operands" => @operands.map { |operand| operand.is_a?(CalendarQuery) ? operand.to_h : operand }
      }
    end
    alias to_dict to_h
  end

  class Calendars
    DATE_COLUMNS = %i[
      amended_date
      date
      event_start_date
      event_time
      filing_date
      payable_on
    ].freeze

    NUMERIC_ZERO_AS_NIL = {
      "sp_earnings" => %i[eps_estimate reported_eps surprise_percent],
      "ipo_info" => %i[price_from price_to price shares],
      "economic_event" => %i[actual expected last revised],
      "splits" => []
    }.freeze

    COLUMN_RENAMES = {
      "Amended Date" => :amended_date,
      "Actual" => :actual,
      "Company Name" => :company,
      "Company" => :company,
      "Country Code" => :region,
      "Currency Name" => :currency_name,
      "Date" => :date,
      "Deal Type" => :deal_type,
      "EPS Estimate" => :eps_estimate,
      "Event" => :event,
      "Event Name" => :event_name,
      "Event Start Date" => :event_start_date,
      "Event Time" => :event_time,
      "Exchange Short Name" => :exchange,
      "Expected" => :expected,
      "Filing Date" => :filing_date,
      "Last" => :last,
      "Market Cap (Intraday)" => :market_cap,
      "Marketcap" => :market_cap,
      "Market Expectation" => :expected,
      "Old Share Worth" => :old_share_worth,
      "Optionable" => :optionable,
      "Optionable?" => :optionable,
      "Payable On" => :payable_on,
      "Period" => :period,
      "Price" => :price,
      "Price From" => :price_from,
      "Price To" => :price_to,
      "Prior to This" => :last,
      "Region" => :region,
      "Reported EPS" => :reported_eps,
      "Revised" => :revised,
      "Revised from" => :revised,
      "Share Worth" => :share_worth,
      "Shares" => :shares,
      "Start Date Time Type" => :timing,
      "Surprise (%)" => :surprise_percent,
      "Surprise(%)" => :surprise_percent,
      "Symbol" => :symbol,
      "Timing" => :timing
    }.freeze

    PREDEFINED_CALENDARS = {
      "sp_earnings" => {
        sort_field: "intradaymarketcap",
        include_fields: %w[
          ticker
          companyshortname
          intradaymarketcap
          eventname
          startdatetime
          startdatetimetype
          epsestimate
          epsactual
          epssurprisepct
        ]
      },
      "ipo_info" => {
        sort_field: "startdatetime",
        include_fields: %w[
          ticker
          companyshortname
          exchange_short_name
          filingdate
          startdatetime
          amendeddate
          pricefrom
          priceto
          offerprice
          currencyname
          shares
          dealtype
        ]
      },
      "economic_event" => {
        sort_field: "startdatetime",
        include_fields: %w[
          econ_release
          country_code
          startdatetime
          period
          after_release_actual
          consensus_estimate
          prior_release_actual
          originally_reported_actual
        ]
      },
      "splits" => {
        sort_field: "startdatetime",
        include_fields: %w[
          ticker
          companyshortname
          startdatetime
          optionable
          old_share_worth
          share_worth
        ]
      }
    }.freeze

    attr_reader :start_date, :end_date

    def initialize(start: nil, end_date: nil, session: nil, client: nil, **options)
      finish = options.key?(:end) ? options[:end] : end_date
      @client = client || session || Client.new
      @start_date = date_string(start) || Date.today.iso8601
      @end_date = date_string(finish) || (Date.iso8601(@start_date) + 7).iso8601
      @calendar_cache = {}
      @request_cache = {}
      @most_active_query = nil
    end

    def earnings_calendar(**options)
      get_earnings_calendar(**options)
    end

    def ipo_info_calendar(**options)
      get_ipo_info_calendar(**options)
    end

    def economic_events_calendar(**options)
      get_economic_events_calendar(**options)
    end

    def splits_calendar(**options)
      get_splits_calendar(**options)
    end

    def get_earnings_calendar(market_cap: nil, filter_most_active: true, start: nil, end_date: nil, limit: 12, offset: 0, force: false, timeout: 10, **options)
      finish = options.key?(:end) ? options[:end] : end_date
      validate_pagination!(limit, offset)

      query = CalendarQuery.new("and", [
        CalendarQuery.new("eq", ["region", "us"]),
        CalendarQuery.new("or", [
          CalendarQuery.new("eq", ["eventtype", "EAD"]),
          CalendarQuery.new("eq", ["eventtype", "ERA"])
        ]),
        *startdatetime_queries(start, finish)
      ])
      query.append(CalendarQuery.new("gte", ["intradaymarketcap", market_cap])) if market_cap
      if filter_most_active && Integer(offset).zero?
        most_active = most_active_operands(market_cap: market_cap, force: force, timeout: timeout)
        query.append(most_active) unless most_active.empty?
      end

      calendar_table("sp_earnings", query, limit: limit, offset: offset, force: force, timeout: timeout)
    end

    def get_ipo_info_calendar(start: nil, end_date: nil, limit: 12, offset: 0, force: false, timeout: 10, **options)
      finish = options.key?(:end) ? options[:end] : end_date
      validate_pagination!(limit, offset)
      start_value, end_value = date_range(start, finish)
      query = CalendarQuery.new("or", [
        CalendarQuery.new("gtelt", ["startdatetime", start_value, end_value]),
        CalendarQuery.new("gtelt", ["filingdate", start_value, end_value]),
        CalendarQuery.new("gtelt", ["amendeddate", start_value, end_value])
      ])

      calendar_table("ipo_info", query, limit: limit, offset: offset, force: force, timeout: timeout)
    end

    def get_economic_events_calendar(start: nil, end_date: nil, limit: 12, offset: 0, force: false, timeout: 10, **options)
      finish = options.key?(:end) ? options[:end] : end_date
      validate_pagination!(limit, offset)
      query = CalendarQuery.new("and", startdatetime_queries(start, finish))

      calendar_table("economic_event", query, limit: limit, offset: offset, force: force, timeout: timeout)
    end

    def get_splits_calendar(start: nil, end_date: nil, limit: 12, offset: 0, force: false, timeout: 10, **options)
      finish = options.key?(:end) ? options[:end] : end_date
      validate_pagination!(limit, offset)
      query = CalendarQuery.new("and", startdatetime_queries(start, finish))

      calendar_table("splits", query, limit: limit, offset: offset, force: force, timeout: timeout)
    end

    private

    def calendar_table(calendar_type, query, limit:, offset:, force:, timeout:)
      config = PREDEFINED_CALENDARS.fetch(calendar_type)
      body = {
        "sortType" => "DESC",
        "entityIdType" => calendar_type,
        "sortField" => config.fetch(:sort_field),
        "includeFields" => config.fetch(:include_fields),
        "size" => [Integer(limit), 100].min,
        "offset" => Integer(offset),
        "query" => query.to_h
      }
      cache_key = [calendar_type, body]
      document =
        if !force && @request_cache[calendar_type] == body && @calendar_cache.key?(cache_key)
          @calendar_cache.fetch(cache_key)
        else
          @request_cache[calendar_type] = body
          @client.calendar(
            calendar_type: calendar_type,
            query: body.fetch("query"),
            include_fields: body.fetch("includeFields"),
            sort_field: body.fetch("sortField"),
            limit: body.fetch("size"),
            offset: body.fetch("offset"),
            timeout: timeout
          )
        end

      table = table_from_document(calendar_type, document)
      @calendar_cache[cache_key] = document
      table
    end

    def most_active_operands(market_cap:, force:, timeout:)
      return @most_active_query if @most_active_query && !force

      query = CalendarQuery.new("or", [])
      result = Ryfinance.screen("most_actives", client: @client, count: 200, timeout: timeout)
      Array(result[:quotes]).each do |quote|
        symbol = quote[:symbol]
        quote_market_cap = quote[:market_cap] || quote[:marketCap]
        next if symbol.to_s.empty?
        next if market_cap && quote_market_cap.to_f < market_cap.to_f

        query.append(CalendarQuery.new("eq", ["ticker", symbol]))
      end
      @most_active_query = query
    rescue Error, KeyError
      @most_active_query = query
    end

    def table_from_document(calendar_type, document)
      columns = calendar_columns(document)
      rows = Array(document["rows"] || document[:rows]).map do |values|
        columns.each_with_index.each_with_object({}) do |(column, index), row|
          row[column] = normalize_calendar_value(calendar_type, column, values[index])
        end.then { |row| Utils.compact_nil(row) }
      end

      Table.new(rows, columns: columns)
    end

    def calendar_columns(document)
      Array(document["columns"] || document[:columns]).map do |column|
        label = column["label"] || column[:label]
        label = "Timing" if label == "Event Start Date" && (column["type"] || column[:type]) == "STRING"
        calendar_column_key(label)
      end
    end

    def calendar_column_key(label)
      COLUMN_RENAMES[label.to_s] || label.to_s
                                     .gsub("(%)", " percent")
                                     .gsub("?", "")
                                     .gsub(/[^A-Za-z0-9]+/, "_")
                                     .gsub(/\A_+|_+\z/, "")
                                     .downcase
                                     .to_sym
    end

    def normalize_calendar_value(calendar_type, key, value)
      return nil if value.nil?
      return nil if NUMERIC_ZERO_AS_NIL.fetch(calendar_type).include?(key) && numeric_zero?(value)
      return parse_calendar_date(value) if DATE_COLUMNS.include?(key)

      value
    end

    def numeric_zero?(value)
      Float(value).zero?
    rescue ArgumentError, TypeError
      false
    end

    def parse_calendar_date(value)
      case value
      when Time
        value.utc
      when Integer
        Utils.yahoo_date(value)
      when Numeric
        Utils.yahoo_date(value.to_i)
      else
        text = value.to_s
        return nil if text.empty?
        return Utils.yahoo_date(text.to_i) if text.match?(/\A\d+\z/)

        deterministic_text = text.match?(/[zZ]|[+-]\d{2}:?\d{2}\z/) ? text : "#{text} UTC"
        Time.parse(deterministic_text).utc
      end
    rescue ArgumentError
      value
    end

    def startdatetime_queries(start, finish)
      start_value, end_value = date_range(start, finish)
      [
        CalendarQuery.new("gte", ["startdatetime", start_value]),
        CalendarQuery.new("lte", ["startdatetime", end_value])
      ]
    end

    def date_range(start, finish)
      [date_string(start) || @start_date, date_string(finish) || @end_date]
    end

    def date_string(value)
      return nil if value.nil?

      case value
      when Date
        value.iso8601
      when Time
        value.utc.to_date.iso8601
      else
        text = value.to_s
        return Time.at(text.to_i).utc.to_date.iso8601 if text.match?(/\A\d+\z/)

        Date.iso8601(text).iso8601
      end
    rescue ArgumentError
      Time.parse(value.to_s).utc.to_date.iso8601
    end

    def validate_pagination!(limit, offset)
      raise ArgumentError, "limit must be positive" unless Integer(limit).positive?
      raise ArgumentError, "offset must be zero or greater" if Integer(offset).negative?
    end
  end
end
