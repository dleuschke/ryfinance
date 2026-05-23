# frozen_string_literal: true

module Ryfinance
  class QueryBase
    LOGICAL_OPERATORS = %w[AND OR].freeze
    VALUE_OPERATORS = %w[EQ IS-IN BTWN GT LT GTE LTE].freeze
    OPERATORS = (LOGICAL_OPERATORS + VALUE_OPERATORS).freeze

    class << self
      attr_reader :quote_type

      def valid_fields
        self::VALID_FIELDS
      end

      def valid_values
        self::VALID_VALUES
      end
    end

    attr_reader :operator, :operand

    def initialize(operator, operand)
      @operator = normalize_operator(operator)
      @operand = normalize_operand(operand)
      validate!
    end

    def to_h
      {
        "operator" => @operator,
        "operands" => @operand.map { |value| value.is_a?(QueryBase) ? value.to_h : value }
      }
    end
    alias to_dict to_h

    def inspect
      "#{self.class.name.split('::').last}(#{@operator}, #{@operand.inspect})"
    end

    private

    def normalize_operator(operator)
      operator.to_s.tr("_", "-").upcase
    end

    def normalize_operand(operand)
      Array(operand)
    end

    def validate!
      raise ArgumentError, "operator must be one of: #{OPERATORS.join(', ')}" unless OPERATORS.include?(@operator)

      if LOGICAL_OPERATORS.include?(@operator)
        validate_logical_operand!
      else
        validate_value_operand!
      end
    end

    def validate_logical_operand!
      unless @operand.all? { |value| value.is_a?(QueryBase) }
        raise ArgumentError, "#{@operator} operands must all be query objects"
      end

      raise ArgumentError, "#{@operator} requires at least one nested query" if @operand.empty?
    end

    def validate_value_operand!
      field = @operand.first
      raise ArgumentError, "#{@operator} first operand must be a field name" unless field.is_a?(String) || field.is_a?(Symbol)

      case @operator
      when "IS-IN"
        raise ArgumentError, "IS-IN requires a field and at least one value" if @operand.length < 2
      when "BTWN"
        raise ArgumentError, "BTWN requires a field, lower bound, and upper bound" unless @operand.length == 3
      else
        raise ArgumentError, "#{@operator} requires exactly a field and value" unless @operand.length == 2
      end
    end
  end

  class EquityQuery < QueryBase
    @quote_type = "EQUITY"

    VALID_FIELDS = {
      eq_fields: %w[exchange industry peer_group region sector],
      price: %w[eodprice fiftytwowkpercentchange intradaymarketcap intradayprice intradaypricechange percentchange],
      trading: %w[avgdailyvol3m beta dayvolume eodvolume pctheldinsider pctheldinst],
      valuation: %w[lastclosepriceearnings.lasttwelvemonths pegratio_5y peratio.lasttwelvemonths pricebookratio.quarterly],
      profitability: %w[forward_dividend_yield returnonassets.lasttwelvemonths returnonequity.lasttwelvemonths],
      income_statement: %w[epsgrowth.lasttwelvemonths quarterlyrevenuegrowth.quarterly totalrevenues.lasttwelvemonths],
      balance_sheet: %w[intradaymarketcap totalassets.lasttwelvemonths totaldebt.lasttwelvemonths totalsharesoutstanding],
      short_interest: %w[short_interest.value short_percentage_of_shares_outstanding.value short_percentage_of_float.value],
      esg: %w[environmental_score esg_score governance_score social_score]
    }.freeze

    VALID_VALUES = {
      region: %w[us ca gb de fr hk jp au in br mx sg],
      exchange: %w[ASE NAS NCM NGM NMS NYQ PCX PNK OQB OQX TOR VAN LSE GER PAR HKG JPX ASX NSI SAO],
      sector: [
        "Basic Materials", "Communication Services", "Consumer Cyclical", "Consumer Defensive",
        "Energy", "Financial Services", "Healthcare", "Industrials", "Real Estate",
        "Technology", "Utilities"
      ]
    }.freeze
  end

  class FundQuery < QueryBase
    @quote_type = "MUTUALFUND"

    VALID_FIELDS = {
      eq_fields: %w[categoryname exchange fundfamily fundcategory region],
      price: %w[intradayprice percentchange fundnetassets],
      performance: %w[annualreturnnavy1 annualreturnnavy3 annualreturnnavy5 annualreturnnavy1categoryrank performanceratingoverall],
      risk: %w[riskratingoverall riskratingoverallcategoryrank],
      expenses: %w[annualreportnetexpenseratio initialinvestment]
    }.freeze

    VALID_VALUES = {
      exchange: %w[NAS],
      performanceratingoverall: [1, 2, 3, 4, 5],
      riskratingoverall: [1, 2, 3, 4, 5]
    }.freeze
  end

  class ETFQuery < QueryBase
    @quote_type = "ETF"

    VALID_FIELDS = {
      eq_fields: %w[categoryname exchange fundfamily region],
      price: %w[intradayprice percentchange fundnetassets],
      performance: %w[annualreturnnavy1 annualreturnnavy3 annualreturnnavy5 performanceratingoverall],
      expenses: %w[annualreportnetexpenseratio],
      holdings: %w[holdingcount top10holdings]
    }.freeze

    VALID_VALUES = {
      region: %w[us ca gb de fr hk jp au in br mx sg],
      performanceratingoverall: [1, 2, 3, 4, 5]
    }.freeze
  end

  PREDEFINED_SCREENER_BODY_DEFAULTS = {
    "offset" => 0,
    "count" => 25,
    "userId" => "",
    "userIdType" => "guid"
  }.freeze

  PREDEFINED_SCREENER_QUERIES = {
    "aggressive_small_caps" => {
      "sortField" => "eodvolume",
      "sortType" => "DESC",
      "query" => EquityQuery.new("and", [
        EquityQuery.new("is-in", ["exchange", "NMS", "NYQ"]),
        EquityQuery.new("lt", ["epsgrowth.lasttwelvemonths", 15])
      ])
    },
    "day_gainers" => {
      "sortField" => "percentchange",
      "sortType" => "DESC",
      "query" => EquityQuery.new("and", [
        EquityQuery.new("gt", ["percentchange", 3]),
        EquityQuery.new("eq", ["region", "us"]),
        EquityQuery.new("gte", ["intradaymarketcap", 2_000_000_000]),
        EquityQuery.new("gte", ["intradayprice", 5]),
        EquityQuery.new("gt", ["dayvolume", 15_000])
      ])
    },
    "day_losers" => {
      "sortField" => "percentchange",
      "sortType" => "ASC",
      "query" => EquityQuery.new("and", [
        EquityQuery.new("lt", ["percentchange", -2.5]),
        EquityQuery.new("eq", ["region", "us"]),
        EquityQuery.new("gte", ["intradaymarketcap", 2_000_000_000]),
        EquityQuery.new("gte", ["intradayprice", 5]),
        EquityQuery.new("gt", ["dayvolume", 20_000])
      ])
    },
    "growth_technology_stocks" => {
      "sortField" => "eodvolume",
      "sortType" => "DESC",
      "query" => EquityQuery.new("and", [
        EquityQuery.new("gte", ["quarterlyrevenuegrowth.quarterly", 25]),
        EquityQuery.new("gte", ["epsgrowth.lasttwelvemonths", 25]),
        EquityQuery.new("eq", ["sector", "Technology"]),
        EquityQuery.new("is-in", ["exchange", "NMS", "NYQ"])
      ])
    },
    "most_actives" => {
      "sortField" => "dayvolume",
      "sortType" => "DESC",
      "query" => EquityQuery.new("and", [
        EquityQuery.new("eq", ["region", "us"]),
        EquityQuery.new("gte", ["intradaymarketcap", 2_000_000_000]),
        EquityQuery.new("gt", ["dayvolume", 5_000_000])
      ])
    },
    "most_shorted_stocks" => {
      "offset" => 0,
      "count" => 25,
      "sortField" => "short_percentage_of_shares_outstanding.value",
      "sortType" => "DESC",
      "query" => EquityQuery.new("and", [
        EquityQuery.new("eq", ["region", "us"]),
        EquityQuery.new("gt", ["intradayprice", 1]),
        EquityQuery.new("gt", ["avgdailyvol3m", 200_000])
      ])
    },
    "small_cap_gainers" => {
      "sortField" => "eodvolume",
      "sortType" => "DESC",
      "query" => EquityQuery.new("and", [
        EquityQuery.new("lt", ["intradaymarketcap", 2_000_000_000]),
        EquityQuery.new("is-in", ["exchange", "NMS", "NYQ"])
      ])
    },
    "undervalued_growth_stocks" => {
      "sortField" => "eodvolume",
      "sortType" => "DESC",
      "query" => EquityQuery.new("and", [
        EquityQuery.new("btwn", ["peratio.lasttwelvemonths", 0, 20]),
        EquityQuery.new("lt", ["pegratio_5y", 1]),
        EquityQuery.new("gte", ["epsgrowth.lasttwelvemonths", 25]),
        EquityQuery.new("is-in", ["exchange", "NMS", "NYQ"])
      ])
    },
    "undervalued_large_caps" => {
      "sortField" => "eodvolume",
      "sortType" => "DESC",
      "query" => EquityQuery.new("and", [
        EquityQuery.new("btwn", ["peratio.lasttwelvemonths", 0, 20]),
        EquityQuery.new("lt", ["pegratio_5y", 1]),
        EquityQuery.new("btwn", ["intradaymarketcap", 10_000_000_000, 100_000_000_000]),
        EquityQuery.new("is-in", ["exchange", "NMS", "NYQ"])
      ])
    },
    "conservative_foreign_funds" => {
      "sortField" => "fundnetassets",
      "sortType" => "DESC",
      "query" => FundQuery.new("and", [
        FundQuery.new("is-in", ["categoryname", "Foreign Large Value", "Foreign Large Blend", "Foreign Large Growth", "Foreign Small/Mid Growth", "Foreign Small/Mid Blend", "Foreign Small/Mid Value"]),
        FundQuery.new("is-in", ["performanceratingoverall", 4, 5]),
        FundQuery.new("lt", ["initialinvestment", 100_001]),
        FundQuery.new("lt", ["annualreturnnavy1categoryrank", 50]),
        FundQuery.new("is-in", ["riskratingoverall", 1, 2, 3]),
        FundQuery.new("eq", ["exchange", "NAS"])
      ])
    },
    "high_yield_bond" => {
      "sortField" => "fundnetassets",
      "sortType" => "DESC",
      "query" => FundQuery.new("and", [
        FundQuery.new("is-in", ["performanceratingoverall", 4, 5]),
        FundQuery.new("lt", ["initialinvestment", 100_001]),
        FundQuery.new("lt", ["annualreturnnavy1categoryrank", 50]),
        FundQuery.new("is-in", ["riskratingoverall", 1, 2, 3]),
        FundQuery.new("eq", ["categoryname", "High Yield Bond"]),
        FundQuery.new("eq", ["exchange", "NAS"])
      ])
    },
    "portfolio_anchors" => {
      "sortField" => "fundnetassets",
      "sortType" => "DESC",
      "query" => FundQuery.new("and", [
        FundQuery.new("eq", ["categoryname", "Large Blend"]),
        FundQuery.new("is-in", ["performanceratingoverall", 4, 5]),
        FundQuery.new("lt", ["initialinvestment", 100_001]),
        FundQuery.new("lt", ["annualreturnnavy1categoryrank", 50]),
        FundQuery.new("eq", ["exchange", "NAS"])
      ])
    },
    "solid_large_growth_funds" => {
      "sortField" => "fundnetassets",
      "sortType" => "DESC",
      "query" => FundQuery.new("and", [
        FundQuery.new("eq", ["categoryname", "Large Growth"]),
        FundQuery.new("is-in", ["performanceratingoverall", 4, 5]),
        FundQuery.new("lt", ["initialinvestment", 100_001]),
        FundQuery.new("lt", ["annualreturnnavy1categoryrank", 50]),
        FundQuery.new("eq", ["exchange", "NAS"])
      ])
    },
    "solid_midcap_growth_funds" => {
      "sortField" => "fundnetassets",
      "sortType" => "DESC",
      "query" => FundQuery.new("and", [
        FundQuery.new("eq", ["categoryname", "Mid-Cap Growth"]),
        FundQuery.new("is-in", ["performanceratingoverall", 4, 5]),
        FundQuery.new("lt", ["initialinvestment", 100_001]),
        FundQuery.new("lt", ["annualreturnnavy1categoryrank", 50]),
        FundQuery.new("eq", ["exchange", "NAS"])
      ])
    },
    "top_mutual_funds" => {
      "sortField" => "percentchange",
      "sortType" => "DESC",
      "query" => FundQuery.new("and", [
        FundQuery.new("gt", ["intradayprice", 15]),
        FundQuery.new("is-in", ["performanceratingoverall", 4, 5]),
        FundQuery.new("gt", ["initialinvestment", 1_000]),
        FundQuery.new("eq", ["exchange", "NAS"])
      ])
    },
    "top_etfs_us" => {
      "sortField" => "percentchange",
      "sortType" => "DESC",
      "query" => ETFQuery.new("and", [
        ETFQuery.new("gt", ["intradayprice", 10]),
        ETFQuery.new("is-in", ["performanceratingoverall", 4, 5]),
        ETFQuery.new("eq", ["region", "us"])
      ])
    },
    "top_performing_etfs" => {
      "sortField" => "annualreportnetexpenseratio",
      "sortType" => "ASC",
      "query" => ETFQuery.new("and", [
        ETFQuery.new("eq", ["region", "us"]),
        ETFQuery.new("is-in", ["performanceratingoverall", 4, 5]),
        ETFQuery.new("gt", ["intradayprice", 10])
      ])
    },
    "technology_etfs" => {
      "sortField" => "annualreportnetexpenseratio",
      "sortType" => "ASC",
      "query" => ETFQuery.new("and", [
        ETFQuery.new("eq", ["region", "us"]),
        ETFQuery.new("eq", ["categoryname", "Technology"])
      ])
    },
    "bond_etfs" => {
      "sortField" => "annualreportnetexpenseratio",
      "sortType" => "ASC",
      "query" => ETFQuery.new("and", [
        ETFQuery.new("eq", ["region", "us"]),
        ETFQuery.new("is-in", ["categoryname", "Corporate Bond", "Emerging Markets Bond", "Emerging-Markets Local-Currency Bond", "High Yield Bond", "Intermediate-Term Bond", "Long-Term Bond", "Inflation-Protected Bond", "Multisector Bond", "Nontraditional Bond", "Short-Term Bond", "Ultrashort Bond", "World Bond"])
      ])
    }
  }.freeze

  class << self
    def predefined_screener_queries
      PREDEFINED_SCREENER_QUERIES
    end
  end
end

