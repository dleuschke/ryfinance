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
      operator = @operator
      operand = @operand

      if @operator == "IS-IN"
        operator = "OR"
        operand = @operand.drop(1).map { |value| self.class.new("eq", [@operand.first, value]) }
      end

      {
        "operator" => operator,
        "operands" => operand.map { |value| value.is_a?(QueryBase) ? value.to_h : value }
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

      raise ArgumentError, "#{@operator} requires at least two nested queries" if @operand.length <= 1
    end

    def validate_value_operand!
      field = @operand.first
      raise ArgumentError, "#{@operator} first operand must be a field name" unless field.is_a?(String) || field.is_a?(Symbol)

      field = field.to_s
      @operand[0] = field
      validate_field!(field)

      case @operator
      when "IS-IN"
        raise ArgumentError, "IS-IN requires a field and at least one value" if @operand.length < 2
        validate_enum_values!(field, 1)
      when "BTWN"
        raise ArgumentError, "BTWN requires a field, lower bound, and upper bound" unless @operand.length == 3
        validate_numeric_value!(1)
        validate_numeric_value!(2)
      when "GT", "LT", "GTE", "LTE"
        raise ArgumentError, "#{@operator} requires exactly a field and value" unless @operand.length == 2
        validate_numeric_value!(1)
      else
        raise ArgumentError, "#{@operator} requires exactly a field and value" unless @operand.length == 2
        validate_enum_values!(field, 1)
      end
    end

    def validate_field!(field)
      return if self.class.valid_fields.values.any? { |fields| fields.map(&:to_s).include?(field) }

      raise ArgumentError, "invalid field for #{self.class.name.split('::').last}: #{field}"
    end

    def validate_numeric_value!(index)
      return if @operand[index].is_a?(Numeric)

      raise ArgumentError, "#{@operator} comparison values must be numeric"
    end

    def validate_enum_values!(field, first_value_index)
      allowed = valid_values_for(field)
      return if allowed.nil? || allowed.empty?

      @operand[first_value_index..].each_with_index do |value, offset|
        normalized = value.is_a?(Symbol) ? value.to_s : value
        unless allowed.include?(normalized)
          raise ArgumentError, "invalid value for #{self.class.name.split('::').last} #{field}: #{value}"
        end

        @operand[first_value_index + offset] = normalized
      end
    end

    def valid_values_for(field)
      values = self.class.valid_values[field.to_sym] || self.class.valid_values[field.to_s]
      flatten_valid_values(values)
    end

    def flatten_valid_values(values)
      case values
      when Hash
        values.values.flat_map { |entry| flatten_valid_values(entry) }.uniq
      when nil
        nil
      else
        Array(values)
      end
    end
  end

  class EquityQuery < QueryBase
    @quote_type = "EQUITY"

    VALID_FIELDS = {
      eq_fields: %w[exchange industry peer_group region sector],
      price: %w[
        eodprice fiftytwowkpercentchange intradaymarketcap intradayprice
        intradaypricechange lastclose52weekhigh.lasttwelvemonths
        lastclose52weeklow.lasttwelvemonths lastclosemarketcap.lasttwelvemonths
        percentchange
      ],
      trading: %w[avgdailyvol3m beta dayvolume eodvolume pctheldinsider pctheldinst],
      short_interest: %w[
        days_to_cover_short.value short_interest.value
        short_interest_percentage_change.value short_percentage_of_float.value
        short_percentage_of_shares_outstanding.value
      ],
      valuation: %w[
        bookvalueshare.lasttwelvemonths lastclosemarketcaptotalrevenue.lasttwelvemonths
        lastclosepriceearnings.lasttwelvemonths lastclosepricetangiblebookvalue.lasttwelvemonths
        lastclosetevtotalrevenue.lasttwelvemonths pegratio_5y
        peratio.lasttwelvemonths pricebookratio.quarterly
      ],
      profitability: %w[
        consecutive_years_of_dividend_growth_count forward_dividend_per_share
        forward_dividend_yield returnonassets.lasttwelvemonths
        returnonequity.lasttwelvemonths returnontotalcapital.lasttwelvemonths
      ],
      leverage: %w[
        ebitdainterestexpense.lasttwelvemonths ebitinterestexpense.lasttwelvemonths
        lastclosetevebit.lasttwelvemonths lastclosetevebitda.lasttwelvemonths
        ltdebtequity.lasttwelvemonths netdebtebitda.lasttwelvemonths
        totaldebtebitda.lasttwelvemonths totaldebtequity.lasttwelvemonths
      ],
      liquidity: %w[
        altmanzscoreusingtheaveragestockinformationforaperiod.lasttwelvemonths
        currentratio.lasttwelvemonths operatingcashflowtocurrentliabilities.lasttwelvemonths
        quickratio.lasttwelvemonths
      ],
      income_statement: %w[
        basicepscontinuingoperations.lasttwelvemonths dilutedeps1yrgrowth.lasttwelvemonths
        dilutedepscontinuingoperations.lasttwelvemonths ebit.lasttwelvemonths
        ebitda.lasttwelvemonths ebitda1yrgrowth.lasttwelvemonths
        ebitdamargin.lasttwelvemonths epsgrowth.lasttwelvemonths
        grossprofit.lasttwelvemonths grossprofitmargin.lasttwelvemonths
        netepsbasic.lasttwelvemonths netepsdiluted.lasttwelvemonths
        netincome1yrgrowth.lasttwelvemonths netincomeis.lasttwelvemonths
        netincomemargin.lasttwelvemonths operatingincome.lasttwelvemonths
        quarterlyrevenuegrowth.quarterly totalrevenues.lasttwelvemonths
        totalrevenues1yrgrowth.lasttwelvemonths
      ],
      balance_sheet: %w[
        intradaymarketcap totalassets.lasttwelvemonths totalcashandshortterminvestments.lasttwelvemonths
        totalcommonsharesoutstanding.lasttwelvemonths totalcommonequity.lasttwelvemonths
        totalcurrentassets.lasttwelvemonths totalcurrentliabilities.lasttwelvemonths
        totaldebt.lasttwelvemonths totalequity.lasttwelvemonths totalsharesoutstanding
      ],
      cash_flow: %w[
        capitalexpenditure.lasttwelvemonths cashfromoperations.lasttwelvemonths
        cashfromoperations1yrgrowth.lasttwelvemonths forward_dividend_yield
        leveredfreecashflow.lasttwelvemonths leveredfreecashflow1yrgrowth.lasttwelvemonths
        unleveredfreecashflow.lasttwelvemonths
      ],
      esg: %w[environmental_score esg_score governance_score highest_controversy social_score]
    }.freeze

    VALID_VALUES = {
      region: %w[
        ae ar at au be br ca ch cl cn co cz de dk ee eg es fi fr gb gr hk hu id
        ie il in is it jp kr kw lk lt lv mx my nl no nz pe ph pk pl pt qa ro ru
        sa se sg sr th tr tw us ve vn za
      ],
      exchange: %w[
        AQS ASE ASX ATH BER BSE BTS BUD BRU BUE BVB CCS CNQ CPH CSE CXA CXE CXI
        DFM DOH DUS DXE EBS ENX EUX FKA FRA GER HAM HAN HEL HKG ICE IOB ISE IST
        JKT JNB JPX KAR KLS KOE KSC KUW LIT LIS LSE MAD MCE MCX MDD MEX MIL MUN
        NAE NCM NEO NGM NMS NSI NYQ NZE OEM OQB OQX OSA OSL PAR PCX PHP PHS PNK
        PRA RIS SAO SAP SAU SES SET SGO SHH SHZ STO STU TAI TAL TLO TLV TOR TWO
        VAN VIE VSE WSE YHD
      ],
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
      eq_fields: %w[
        annualreturnnavy1categoryrank categoryname exchange fundcategory fundfamily
        initialinvestment performanceratingoverall region riskratingoverall
      ],
      price: %w[eodprice fundnetassets intradayprice intradaypricechange percentchange],
      performance: %w[
        annualreturnnavy1 annualreturnnavy3 annualreturnnavy5 annualreturnnavy1categoryrank
        performanceratingoverall
      ],
      risk: %w[riskratingoverall riskratingoverallcategoryrank],
      expenses: %w[annualreportnetexpenseratio initialinvestment]
    }.freeze

    VALID_VALUES = {
      exchange: %w[
        ASE ASX ATH BER BSE BRU BUE BVB CCS CNQ CPH CSE CXA CXE DFM DOH DUS EBS
        ENX EUX FKA FRA GER HAM HAN HEL HKG ICE IOB ISE IST JKT JNB JPX KAR KLS
        KOE KSC KUW LIT LIS LSE MAD MCE MCX MEX MIL MUN NAS NCM NEO NGM NMS NSI
        NYQ NZE OEM OGM OQB OSA OSL PAR PHP PHS PNK PRA RIS SAO SAP SAU SES SET
        SGO SHH SHZ STO STU TAI TAL TLV TOR TWO VAN VIE VSE WCB WSE
      ],
      performanceratingoverall: [1, 2, 3, 4, 5],
      riskratingoverall: [1, 2, 3, 4, 5]
    }.freeze
  end

  class ETFQuery < QueryBase
    @quote_type = "ETF"

    VALID_FIELDS = {
      eq_fields: %w[
        categoryname exchange fundfamily fundfamilyname morningstar_economic_moat
        morningstar_moat_trend morningstar_rating_change morningstar_stewardship
        morningstar_uncertainty primary_sector region
      ],
      fundamentals: %w[fundnetassets ticker],
      price: %w[eodprice fundnetassets intradayprice intradaypricechange percentchange],
      feesandexpenses: %w[annualreportgrossexpenseratio annualreportnetexpenseratio turnoverratio],
      historicalperformance: %w[annualreturnnavy1 annualreturnnavy1categoryrank annualreturnnavy3 annualreturnnavy5],
      keystats: %w[avgdailyvol3m dayvolume eodvolume fiftytwowkpercentchange percentchange],
      morningstar_rating: %w[
        morningstar_last_close_price_to_fair_value morningstar_rating
        morningstar_rating_updated_time
      ],
      performance: %w[annualreturnnavy1 annualreturnnavy3 annualreturnnavy5 performanceratingoverall],
      portfoliostatistics: %w[marketcapitalvaluelong],
      purchasedetails: %w[initialinvestment],
      trailingperformance: %w[
        performanceratingoverall quarterendtrailingreturnytd riskratingoverall
        trailing_3m_return trailing_ytd_return
      ],
      holdings: %w[holdingcount top10holdings]
    }.freeze

    VALID_VALUES = {
      region: %w[
        ae ar at au be br ca ch cl cn co cz de dk ee eg es fi fr gb gr hk hu id
        ie il in is it jp kr kw lk lt lv mx my nl no nz pe ph pk pl pt qa ro ru
        sa se sg sr th tr tw us ve vn za
      ],
      exchange: %w[
        AQS ASE ASX ATH BER BSE BTS BUD BRU BUE BVB CCS CNQ CPH CSE CXA CXE CXI
        DFM DOH DUS DXE EBS ENX EUX FKA FRA GER HAM HAN HEL HKG ICE IOB ISE IST
        JKT JNB JPX KAR KLS KOE KSC KUW LIT LIS LSE MAD MCE MCX MDD MEX MIL MUN
        NAE NCM NEO NGM NMS NSI NYQ NZE OEM OQB OQX OSA OSL PAR PCX PHP PHS PNK
        PRA RIS SAO SAP SAU SES SET SGO SHH SHZ STO STU TAI TAL TLO TLV TOR TWO
        VAN VIE VSE WSE YHD
      ],
      morningstar_economic_moat: ["Narrow", "None", "Wide"],
      morningstar_moat_trend: %w[Negative Positive Stable],
      morningstar_rating_change: %w[Downgrade Upgrade],
      morningstar_stewardship: %w[Exemplary Poor Standard],
      morningstar_uncertainty: ["Low", "Medium", "High", "Very High", "Extreme"],
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
