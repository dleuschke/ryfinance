# frozen_string_literal: true

module Ryfinance
  class FundsData
    MODULES = %w[quoteType summaryProfile topHoldings fundProfile].freeze
    FUND_QUOTE_TYPES = ["ETF", "MUTUALFUND", "MUTUAL FUND"].freeze

    ASSET_CLASS_KEYS = %i[
      cash_position stock_position bond_position convertible_position
      preferred_position other_position
    ].freeze

    EQUITY_HOLDING_METRICS = [
      [:price_to_earnings, :price_to_earnings_cat, "Price/Earnings"],
      [:price_to_book, :price_to_book_cat, "Price/Book"],
      [:price_to_sales, :price_to_sales_cat, "Price/Sales"],
      [:price_to_cashflow, :price_to_cashflow_cat, "Price/Cashflow"],
      [:median_market_cap, :median_market_cap_cat, "Median Market Cap"],
      [:three_year_earnings_growth, :three_year_earnings_growth_cat, "3 Year Earnings Growth"]
    ].freeze

    BOND_HOLDING_METRICS = [
      [:maturity, :maturity_cat, "Maturity"],
      [:duration, :duration_cat, "Duration"],
      [:credit_quality, :credit_quality_cat, "Credit Quality"]
    ].freeze

    FUND_OPERATION_METRICS = [
      [:annual_report_expense_ratio, :annual_report_expense_ratio, "Annual Report Expense Ratio"],
      [:annual_holdings_turnover, :annual_holdings_turnover, "Annual Holdings Turnover"],
      [:total_net_assets, :total_net_assets, "Total Net Assets"]
    ].freeze

    attr_reader :symbol

    def initialize(symbol, client:, timeout: 10)
      @symbol = symbol.to_s.upcase
      @client = client
      @timeout = timeout
      @fetched = false
      @raw = {}
      @quote_type = nil
      @description = nil
      @fund_overview = {}
      @fund_operations = Table.new([])
      @asset_classes = {}
      @top_holdings = Table.new([])
      @equity_holdings = Table.new([])
      @bond_holdings = Table.new([])
      @bond_ratings = {}
      @sector_weightings = {}
    end

    def fund?
      FUND_QUOTE_TYPES.include?(quote_type.to_s.upcase)
    end

    def quote_type(timeout: nil)
      ensure_fetched(timeout: timeout)
      @quote_type
    end

    def description(timeout: nil)
      ensure_fetched(timeout: timeout)
      @description
    end

    def fund_overview(timeout: nil)
      ensure_fetched(timeout: timeout)
      @fund_overview.dup
    end

    def fund_operations(timeout: nil)
      ensure_fetched(timeout: timeout)
      @fund_operations
    end

    def asset_classes(timeout: nil)
      ensure_fetched(timeout: timeout)
      @asset_classes.dup
    end

    def top_holdings(timeout: nil)
      ensure_fetched(timeout: timeout)
      @top_holdings
    end

    def equity_holdings(timeout: nil)
      ensure_fetched(timeout: timeout)
      @equity_holdings
    end

    def bond_holdings(timeout: nil)
      ensure_fetched(timeout: timeout)
      @bond_holdings
    end

    def bond_ratings(timeout: nil)
      ensure_fetched(timeout: timeout)
      @bond_ratings.dup
    end

    def sector_weightings(timeout: nil)
      ensure_fetched(timeout: timeout)
      @sector_weightings.dup
    end

    def to_h
      ensure_fetched
      {
        symbol: @symbol,
        quote_type: @quote_type,
        description: @description,
        fund_overview: @fund_overview.dup,
        fund_operations: @fund_operations.to_a,
        asset_classes: @asset_classes.dup,
        top_holdings: @top_holdings.to_a,
        equity_holdings: @equity_holdings.to_a,
        bond_holdings: @bond_holdings.to_a,
        bond_ratings: @bond_ratings.dup,
        sector_weightings: @sector_weightings.dup
      }
    end

    private

    def ensure_fetched(timeout: nil)
      fetch_and_parse(timeout: timeout || @timeout) unless @fetched
    end

    def fetch_and_parse(timeout:)
      @raw = Utils.deep_symbolize(Utils.unwrap_value(
        @client.quote_summary(@symbol, modules: MODULES, timeout: timeout)
      ))

      parse_quote_type(@raw.fetch(:quote_type, {}))
      parse_summary_profile(@raw.fetch(:summary_profile, {}))
      parse_top_holdings(@raw.fetch(:top_holdings, {}))
      parse_fund_profile(@raw.fetch(:fund_profile, {}))
      @fetched = true
    end

    def parse_quote_type(data)
      @quote_type = data[:quote_type] || data[:type_disp] || data[:quote_type_disp]
    end

    def parse_summary_profile(data)
      @description = data[:long_business_summary]
    end

    def parse_top_holdings(data)
      @asset_classes = ASSET_CLASS_KEYS.each_with_object({}) do |key, result|
        result[key] = data[key] if data.key?(key)
      end

      @top_holdings = top_holdings_table(data.fetch(:holdings, []))
      @equity_holdings = metric_table(data.fetch(:equity_holdings, {}), EQUITY_HOLDING_METRICS)
      @bond_holdings = metric_table(data.fetch(:bond_holdings, {}), BOND_HOLDING_METRICS)
      @bond_ratings = single_key_array_to_hash(data.fetch(:bond_ratings, []))
      @sector_weightings = single_key_array_to_hash(data.fetch(:sector_weightings, []))
    end

    def parse_fund_profile(data)
      @fund_overview = {
        category_name: data[:category_name],
        family: data[:family],
        legal_type: data[:legal_type]
      }.reject { |_key, value| value.nil? }

      @fund_operations = fund_operations_table(
        data.fetch(:fees_expenses_investment, {}),
        data.fetch(:fees_expenses_investment_cat, {})
      )
    end

    def top_holdings_table(holdings)
      rows = Array(holdings).map do |holding|
        {
          symbol: holding[:symbol],
          name: holding[:holding_name] || holding[:name],
          holding_percent: holding[:holding_percent]
        }
      end

      Table.new(rows, columns: %i[symbol name holding_percent])
    end

    def metric_table(values, metrics)
      return Table.new([]) if values.empty?

      rows = metrics.map do |value_key, category_key, label|
        {
          metric: label,
          value: values[value_key],
          category_average: values[category_key]
        }
      end

      Table.new(rows, columns: %i[metric value category_average])
    end

    def fund_operations_table(values, category_values)
      return Table.new([]) if values.empty? && category_values.empty?

      rows = FUND_OPERATION_METRICS.map do |value_key, category_key, label|
        {
          metric: label,
          value: values[value_key],
          category_average: category_values[category_key]
        }
      end

      Table.new(rows, columns: %i[metric value category_average])
    end

    def single_key_array_to_hash(values)
      Array(values).each_with_object({}) do |entry, result|
        next unless entry.is_a?(Hash)

        entry.each do |key, value|
          result[Utils.symbolize_key(key)] = value
        end
      end
    end
  end
end
