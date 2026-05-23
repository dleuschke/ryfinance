# frozen_string_literal: true

module Ryfinance
  class Ticker
    VALID_PERIODS = %w[1d 5d 1mo 3mo 6mo 1y 2y 5y 10y ytd max].freeze
    VALID_INTERVALS = %w[1m 2m 5m 15m 30m 60m 90m 1h 1d 5d 1wk 1mo 3mo].freeze

    INFO_MODULES = %w[
      assetProfile summaryProfile summaryDetail quoteType price financialData
      defaultKeyStatistics calendarEvents secFilings recommendationTrend
      upgradeDowngradeHistory earningsTrend earnings esgScores majorHoldersBreakdown
      institutionOwnership fundOwnership insiderHolders insiderTransactions
    ].freeze

    MIC_TO_YAHOO_SUFFIX = {
      "XNYS" => "",
      "XNAS" => "",
      "XASE" => "",
      "ARCX" => "",
      "XTSE" => "TO",
      "XTSX" => "V",
      "XLON" => "L",
      "XPAR" => "PA",
      "XAMS" => "AS",
      "XMIL" => "MI",
      "XMAD" => "MC",
      "XFRA" => "F",
      "XETR" => "DE",
      "XSWX" => "SW",
      "XHKG" => "HK",
      "XTKS" => "T",
      "XASX" => "AX",
      "BVMF" => "SA",
      "XNSE" => "NS",
      "XBOM" => "BO",
      "XKRX" => "KS",
      "XSES" => "SI"
    }.freeze

    FAST_INFO_MAP = {
      regular_market_price: :last_price,
      regular_market_previous_close: :previous_close,
      regular_market_open: :open,
      regular_market_day_high: :day_high,
      regular_market_day_low: :day_low,
      regular_market_volume: :last_volume,
      fifty_day_average: :fifty_day_average,
      two_hundred_day_average: :two_hundred_day_average
    }.freeze

    attr_reader :ticker

    def initialize(ticker, session: nil, client: nil)
      @ticker = normalize_ticker(ticker)
      raise InvalidTickerError, "Empty ticker name" if @ticker.empty?

      @client = client || session || Client.new
      @quote_summary_cache = {}
      @fast_quote = nil
      @last_history_metadata = {}
      @options_expirations = nil
      @underlying = {}
    end

    def inspect
      "#<#{self.class.name} #{@ticker}>"
    end

    def history(period: "1mo", interval: "1d", start: nil, end_date: nil, actions: true, auto_adjust: true, back_adjust: false, prepost: false, rounding: false, keepna: false, timeout: 10, **options)
      finish = options.key?(:end) ? options[:end] : end_date
      range = options.fetch(:range, period)

      validate_period!(range) unless start || finish
      validate_interval!(interval)

      params = {
        interval: interval,
        includePrePost: prepost,
        events: "div,splits,capitalGains"
      }

      if start || finish
        params[:period1] = Utils.to_timestamp(start || "1900-01-01")
        params[:period2] = Utils.to_timestamp(finish || Time.now)
      else
        params[:range] = range
      end

      result = @client.chart(@ticker, params: params, timeout: timeout)
      @last_history_metadata = Utils.deep_symbolize(Utils.unwrap_value(result.fetch("meta", {})))
      Ryfinance.timezone_cache.set(@ticker, @last_history_metadata[:exchange_timezone_name])

      table_from_chart(
        result,
        actions: actions,
        auto_adjust: auto_adjust,
        back_adjust: back_adjust,
        rounding: rounding,
        keepna: keepna
      )
    end

    def get_history_metadata
      return @last_history_metadata unless @last_history_metadata.empty?

      history(period: "1d").metadata
    end
    alias history_metadata get_history_metadata

    def get_dividends(period: "max", **options)
      rows = history(period: period, actions: true, auto_adjust: false, **options).filter_map do |row|
        amount = row[:dividends].to_f
        next if amount.zero?

        { date: row[:date], dividend: amount }
      end

      Table.new(rows, columns: %i[date dividend])
    end
    alias dividends get_dividends

    def get_splits(period: "max", **options)
      rows = history(period: period, actions: true, auto_adjust: false, **options).filter_map do |row|
        ratio = row[:stock_splits].to_f
        next if ratio.zero?

        { date: row[:date], stock_split: ratio }
      end

      Table.new(rows, columns: %i[date stock_split])
    end
    alias splits get_splits

    def get_capital_gains(period: "max", **options)
      rows = history(period: period, actions: true, auto_adjust: false, **options).filter_map do |row|
        amount = row[:capital_gains].to_f
        next if amount.zero?

        { date: row[:date], capital_gain: amount }
      end

      Table.new(rows, columns: %i[date capital_gain])
    end
    alias capital_gains get_capital_gains

    def get_actions(period: "max", **options)
      rows = history(period: period, actions: true, auto_adjust: false, **options).filter_map do |row|
        dividend = row[:dividends].to_f
        split = row[:stock_splits].to_f
        gain = row[:capital_gains].to_f
        next if dividend.zero? && split.zero? && gain.zero?

        {
          date: row[:date],
          dividends: dividend,
          stock_splits: split,
          capital_gains: gain
        }
      end

      Table.new(rows, columns: %i[date dividends stock_splits capital_gains])
    end
    alias actions get_actions

    def get_info(timeout: 10)
      summary = quote_summary(INFO_MODULES, timeout: timeout)
      flattened = {}

      summary.each do |module_name, module_data|
        unwrapped = Utils.unwrap_value(module_data)
        next if unwrapped.nil?

        flattened[Utils.symbolize_key(module_name)] = Utils.deep_symbolize(unwrapped)
        next unless unwrapped.is_a?(Hash)

        unwrapped.each do |key, value|
          flattened[Utils.symbolize_key(key)] = Utils.deep_symbolize(value) unless value.nil?
        end
      end

      fast_quote(timeout: timeout).each do |key, value|
        flattened[Utils.symbolize_key(key)] ||= Utils.deep_symbolize(Utils.unwrap_value(value))
      end

      flattened
    end
    alias info get_info

    def get_fast_info(timeout: 10)
      raw = Utils.deep_symbolize(Utils.unwrap_value(fast_quote(timeout: timeout)))
      info = raw.dup

      FAST_INFO_MAP.each do |source, destination|
        info[destination] = raw[source] if raw.key?(source)
      end

      info[:symbol] ||= @ticker
      info
    end
    alias fast_info get_fast_info

    def get_calendar(timeout: 10)
      Utils.deep_symbolize(Utils.unwrap_value(raw_module("calendarEvents", timeout: timeout)))
    end
    alias calendar get_calendar

    def get_sec_filings(timeout: 10)
      Utils.deep_symbolize(Utils.unwrap_value(raw_module("secFilings", timeout: timeout)))
    end
    alias sec_filings get_sec_filings

    def get_recommendations(timeout: 10, as_dict: false)
      table = table_from_array(raw_module("recommendationTrend", timeout: timeout)["trend"])
      as_dict ? table.to_a : table
    end
    alias recommendations get_recommendations

    def get_recommendations_summary(**options)
      get_recommendations(**options)
    end
    alias recommendations_summary get_recommendations_summary

    def get_upgrades_downgrades(timeout: 10, as_dict: false)
      table = table_from_array(raw_module("upgradeDowngradeHistory", timeout: timeout)["history"])
      as_dict ? table.to_a : table
    end
    alias upgrades_downgrades get_upgrades_downgrades

    def get_analyst_price_targets(timeout: 10)
      data = Utils.deep_symbolize(Utils.unwrap_value(raw_module("financialData", timeout: timeout)))
      {
        current: data[:current_price],
        low: data[:target_low_price],
        high: data[:target_high_price],
        mean: data[:target_mean_price],
        median: data[:target_median_price]
      }.compact
    end
    alias analyst_price_targets get_analyst_price_targets

    def get_earnings_estimate(timeout: 10, as_dict: false)
      earnings_trend_table(:earnings_estimate, timeout: timeout, as_dict: as_dict)
    end
    alias earnings_estimate get_earnings_estimate

    def get_revenue_estimate(timeout: 10, as_dict: false)
      earnings_trend_table(:revenue_estimate, timeout: timeout, as_dict: as_dict)
    end
    alias revenue_estimate get_revenue_estimate

    def get_earnings_history(timeout: 10, as_dict: false)
      earnings_trend_table(:earnings_history, timeout: timeout, as_dict: as_dict)
    end
    alias earnings_history get_earnings_history

    def get_eps_trend(timeout: 10, as_dict: false)
      earnings_trend_table(:eps_trend, timeout: timeout, as_dict: as_dict)
    end
    alias eps_trend get_eps_trend

    def get_eps_revisions(timeout: 10, as_dict: false)
      earnings_trend_table(:eps_revisions, timeout: timeout, as_dict: as_dict)
    end
    alias eps_revisions get_eps_revisions

    def get_growth_estimates(timeout: 10, as_dict: false)
      rows = earnings_trends(timeout: timeout).map do |row|
        {
          period: row[:period],
          end_date: row[:end_date],
          growth: row[:growth]
        }
      end
      table = Table.new(rows)
      as_dict ? table.to_a : table
    end
    alias growth_estimates get_growth_estimates

    def get_sustainability(timeout: 10, as_dict: false)
      data = Utils.deep_symbolize(Utils.unwrap_value(raw_module("esgScores", timeout: timeout)))
      table = Table.new(data.empty? ? [] : [data])
      as_dict ? table.to_a : table
    end
    alias sustainability get_sustainability

    def get_major_holders(timeout: 10, as_dict: false)
      data = Utils.deep_symbolize(Utils.unwrap_value(raw_module("majorHoldersBreakdown", timeout: timeout)))
      table = Table.new(data.empty? ? [] : [data])
      as_dict ? table.to_a : table
    end
    alias major_holders get_major_holders

    def get_institutional_holders(timeout: 10, as_dict: false)
      table = table_from_array(raw_module("institutionOwnership", timeout: timeout)["ownershipList"])
      as_dict ? table.to_a : table
    end
    alias institutional_holders get_institutional_holders

    def get_mutualfund_holders(timeout: 10, as_dict: false)
      table = table_from_array(raw_module("fundOwnership", timeout: timeout)["ownershipList"])
      as_dict ? table.to_a : table
    end
    alias mutualfund_holders get_mutualfund_holders

    def get_insider_transactions(timeout: 10, as_dict: false)
      table = table_from_array(raw_module("insiderTransactions", timeout: timeout)["transactions"])
      as_dict ? table.to_a : table
    end
    alias insider_transactions get_insider_transactions

    def get_insider_roster_holders(timeout: 10, as_dict: false)
      table = table_from_array(raw_module("insiderHolders", timeout: timeout)["holders"])
      as_dict ? table.to_a : table
    end
    alias insider_roster_holders get_insider_roster_holders

    def get_insider_purchases(timeout: 10, as_dict: false)
      purchases = raw_module("insiderTransactions", timeout: timeout)["purchases"]
      table = table_from_array(purchases)
      as_dict ? table.to_a : table
    end
    alias insider_purchases get_insider_purchases

    def get_income_stmt(freq: "yearly", pretty: false, as_dict: false, timeout: 10)
      table = statement_table(statement_module("incomeStatementHistory", freq), timeout: timeout)
      as_dict ? table.to_h(index: :end_date) : table
    end
    alias get_incomestmt get_income_stmt
    alias get_financials get_income_stmt

    def income_stmt
      get_income_stmt(pretty: true)
    end
    alias incomestmt income_stmt
    alias financials income_stmt

    def quarterly_income_stmt
      get_income_stmt(freq: "quarterly", pretty: true)
    end
    alias quarterly_incomestmt quarterly_income_stmt
    alias quarterly_financials quarterly_income_stmt

    def ttm_income_stmt
      get_income_stmt(freq: "trailing", pretty: true)
    end
    alias ttm_incomestmt ttm_income_stmt
    alias ttm_financials ttm_income_stmt

    def get_balance_sheet(freq: "yearly", pretty: false, as_dict: false, timeout: 10)
      table = statement_table(statement_module("balanceSheetHistory", freq), timeout: timeout)
      as_dict ? table.to_h(index: :end_date) : table
    end
    alias get_balancesheet get_balance_sheet

    def balance_sheet
      get_balance_sheet(pretty: true)
    end
    alias balancesheet balance_sheet

    def quarterly_balance_sheet
      get_balance_sheet(freq: "quarterly", pretty: true)
    end
    alias quarterly_balancesheet quarterly_balance_sheet

    def get_cash_flow(freq: "yearly", pretty: false, as_dict: false, timeout: 10)
      table = statement_table(statement_module("cashflowStatementHistory", freq), timeout: timeout)
      as_dict ? table.to_h(index: :end_date) : table
    end
    alias get_cashflow get_cash_flow

    def cash_flow
      get_cash_flow(pretty: true)
    end
    alias cashflow cash_flow

    def quarterly_cash_flow
      get_cash_flow(freq: "quarterly", pretty: true)
    end
    alias quarterly_cashflow quarterly_cash_flow

    def ttm_cash_flow
      get_cash_flow(freq: "trailing", pretty: true)
    end
    alias ttm_cashflow ttm_cash_flow

    def get_earnings(freq: "yearly", as_dict: false, timeout: 10)
      data = Utils.deep_symbolize(Utils.unwrap_value(raw_module("earnings", timeout: timeout)))
      chart = data.dig(:financials_chart, freq.to_s.start_with?("quarter") ? :quarterly : :yearly) || []
      table = Table.new(chart)
      as_dict ? table.to_a : table
    end
    alias earnings get_earnings

    def quarterly_earnings
      get_earnings(freq: "quarterly")
    end

    def get_options(timeout: 10)
      load_option_expirations(timeout: timeout).keys
    end
    alias options get_options

    def option_chain(date = nil, tz: nil, timeout: 10)
      response =
        if date.nil?
          @client.options(@ticker, timeout: timeout)
        else
          epoch = option_expiration_epoch(date, timeout: timeout)
          @client.options(@ticker, date: epoch, timeout: timeout)
        end

      option = Array(response["options"]).first || {}
      @underlying = Utils.deep_symbolize(Utils.unwrap_value(response["quote"] || {}))

      OptionChain.new(
        calls: option_table(option["calls"], tz: tz),
        puts: option_table(option["puts"], tz: tz),
        underlying: @underlying
      )
    end

    def get_news(count: 10, tab: "news", timeout: 10)
      unless ["news", "all", "press releases"].include?(tab.to_s.downcase)
        raise ArgumentError, "tab must be one of: news, all, press releases"
      end

      data = @client.search(@ticker, quotes_count: 0, news_count: count, timeout: timeout)
      Array(data["news"]).map { |row| Utils.deep_symbolize(Utils.unwrap_value(row)) }
    end
    alias news get_news

    def get_shares_full(start: nil, end_date: nil, timeout: 10, **options)
      finish = options.key?(:end) ? options[:end] : end_date
      period2 = Utils.to_timestamp(finish || Time.now)
      period1 = Utils.to_timestamp(start || (Time.at(period2) - (548 * 24 * 60 * 60)))

      data = @client.timeseries(
        @ticker,
        types: "shares_out",
        period1: period1,
        period2: period2,
        timeout: timeout
      )
      result = Array(data.dig("timeseries", "result")).find { |entry| entry["shares_out"] }
      timestamps = result&.fetch("timestamp", []) || []
      shares = result&.fetch("shares_out", []) || []

      rows = timestamps.each_with_index.map do |timestamp, index|
        { date: Utils.yahoo_date(timestamp), shares: shares[index] }
      end

      Table.new(rows, columns: %i[date shares])
    end

    def get_isin
      return "-" if @ticker.include?("-") || @ticker.include?("^")

      info[:isin]
    end
    alias isin get_isin

    def live(message_handler = nil, verbose: true, websocket: nil, **options, &block)
      handler = block || message_handler
      socket = websocket || WebSocket.new(verbose: verbose, **options)
      socket.subscribe(@ticker)
      return socket unless handler

      socket.listen(handler)
    end

    private

    def normalize_ticker(value)
      if value.is_a?(Array)
        raise InvalidTickerError, "Ticker tuple must be [symbol, mic_code]" unless value.length == 2

        base_symbol, mic_code = value
        suffix = MIC_TO_YAHOO_SUFFIX.fetch(mic_code.to_s.delete_prefix(".").upcase, mic_code.to_s.delete_prefix("."))
        return suffix.empty? ? base_symbol.to_s.upcase : "#{base_symbol}.#{suffix}".upcase
      end

      value.to_s.strip.upcase
    end

    def validate_period!(period)
      return if period.nil? || VALID_PERIODS.include?(period.to_s)

      raise ArgumentError, "period must be one of: #{VALID_PERIODS.join(', ')}"
    end

    def validate_interval!(interval)
      return if VALID_INTERVALS.include?(interval.to_s)

      raise ArgumentError, "interval must be one of: #{VALID_INTERVALS.join(', ')}"
    end

    def table_from_chart(result, actions:, auto_adjust:, back_adjust:, rounding:, keepna:)
      timestamps = result.fetch("timestamp", [])
      quote = result.dig("indicators", "quote", 0) || {}
      adjclose = result.dig("indicators", "adjclose", 0, "adjclose") || []
      events = result.fetch("events", {})
      dividends = event_amounts(events["dividends"])
      capital_gains = event_amounts(events["capitalGains"])
      splits = split_amounts(events["splits"])

      rows = timestamps.each_with_index.filter_map do |timestamp, index|
        close = value_at(quote, "close", index)
        adj_close = adjclose[index]
        open = value_at(quote, "open", index)
        high = value_at(quote, "high", index)
        low = value_at(quote, "low", index)
        volume = value_at(quote, "volume", index)

        next if !keepna && [open, high, low, close, adj_close, volume].all?(&:nil?)

        if (auto_adjust || back_adjust) && close && adj_close && !close.to_f.zero?
          ratio = adj_close.to_f / close.to_f
          open = open.to_f * ratio if open
          high = high.to_f * ratio if high
          low = low.to_f * ratio if low
          close = adj_close if auto_adjust
        end

        row = {
          date: Utils.yahoo_date(timestamp),
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
          adj_close: adj_close
        }

        if actions
          row[:dividends] = dividends.fetch(timestamp, 0.0)
          row[:stock_splits] = splits.fetch(timestamp, 0.0)
          row[:capital_gains] = capital_gains.fetch(timestamp, 0.0)
        end

        row.transform_values! { |value| Utils.maybe_round(value) } if rounding
        Utils.compact_nil(row)
      end

      columns = %i[date open high low close volume adj_close]
      columns += %i[dividends stock_splits capital_gains] if actions
      Table.new(rows, columns: columns, metadata: @last_history_metadata)
    end

    def value_at(hash, key, index)
      values = hash[key] || hash[Utils.symbolize_key(key)]
      values && values[index]
    end

    def event_amounts(events)
      Array(events).each_with_object({}) do |entry, result|
        data = entry.last
        result[data.fetch("date").to_i] = data.fetch("amount", 0).to_f
      end
    end

    def split_amounts(events)
      Array(events).each_with_object({}) do |entry, result|
        data = entry.last
        numerator = data["numerator"]
        denominator = data["denominator"]
        amount =
          if numerator && denominator && !denominator.to_f.zero?
            numerator.to_f / denominator.to_f
          elsif data["splitRatio"].to_s.include?(":")
            left, right = data["splitRatio"].split(":", 2).map(&:to_f)
            right.zero? ? 0.0 : left / right
          else
            data["splitRatio"].to_f
          end

        result[data.fetch("date").to_i] = amount
      end
    end

    def quote_summary(modules, timeout:)
      key = Array(modules).sort.join(",")
      @quote_summary_cache[key] ||= @client.quote_summary(@ticker, modules: modules, timeout: timeout)
    end

    def raw_module(name, timeout:)
      quote_summary([name], timeout: timeout)[name] || {}
    end

    def fast_quote(timeout:)
      @fast_quote ||= (@client.quote([@ticker], timeout: timeout).first || {})
    end

    def table_from_array(array)
      rows = Array(array).map { |row| Utils.deep_symbolize(Utils.unwrap_value(row)) }
      Table.new(rows)
    end

    def earnings_trends(timeout:)
      Array(raw_module("earningsTrend", timeout: timeout)["trend"]).map do |row|
        Utils.deep_symbolize(Utils.unwrap_value(row))
      end
    end

    def earnings_trend_table(key, timeout:, as_dict:)
      rows = earnings_trends(timeout: timeout).map do |row|
        nested = row[key] || {}
        {
          period: row[:period],
          end_date: row[:end_date],
          **nested
        }
      end
      table = Table.new(rows)
      as_dict ? table.to_a : table
    end

    def statement_module(base, freq)
      return "#{base}Quarterly" if freq.to_s.start_with?("quarter")

      base
    end

    def statement_table(module_name, timeout:)
      data = raw_module(module_name, timeout: timeout)
      statements = data[module_name] || []
      rows = Array(statements).map do |statement|
        row = Utils.deep_symbolize(Utils.unwrap_value(statement))
        row[:end_date] = Utils.yahoo_date(row[:end_date]) if row[:end_date].is_a?(Integer)
        row
      end

      Table.new(rows)
    end

    def load_option_expirations(timeout:)
      return @options_expirations if @options_expirations

      response = @client.options(@ticker, timeout: timeout)
      @underlying = Utils.deep_symbolize(Utils.unwrap_value(response["quote"] || {}))
      @options_expirations = Array(response["expirationDates"]).each_with_object({}) do |timestamp, result|
        result[Utils.expiration_date(timestamp)] = timestamp
      end
    end

    def option_expiration_epoch(date, timeout:)
      expirations = load_option_expirations(timeout: timeout)
      return date if date.is_a?(Integer)

      key = date.respond_to?(:strftime) ? date.strftime("%Y-%m-%d") : date.to_s
      epoch = expirations[key]
      return epoch if epoch

      raise ArgumentError, "Expiration `#{key}` cannot be found. Available expirations are: [#{expirations.keys.join(', ')}]"
    end

    def option_table(options, tz:)
      rows = Array(options).map do |row|
        output = Utils.deep_symbolize(Utils.unwrap_value(row))
        output[:last_trade_date] = Utils.yahoo_date(output[:last_trade_date]) if output[:last_trade_date].is_a?(Integer)
        output
      end

      columns = %i[
        contract_symbol last_trade_date strike last_price bid ask change
        percent_change volume open_interest implied_volatility in_the_money
        contract_size currency
      ]
      Table.new(rows, columns: columns)
    end
  end
end
