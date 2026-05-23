# frozen_string_literal: true

require_relative "test_helper"

class TickerTest < Minitest::Test
  def setup
    @transport = FakeTransport.new
    @transport.route(%r{/v8/finance/chart/}) { chart_fixture }
    @transport.route(%r{/v7/finance/quote}) { quote_fixture }
    @transport.route(%r{/v10/finance/quoteSummary/}) { quote_summary_fixture }
    @transport.route(%r{/v7/finance/options/}) { options_fixture }
    @transport.route(%r{/ws/fundamentals-timeseries/v1/finance/timeseries/}) do
      {
        "timeseries" => {
          "result" => [
            {
              "timestamp" => [1_704_067_200],
              "shares_out" => [7_430_000_000]
            }
          ]
        }
      }
    end
    @transport.route(%r{/v1/finance/search}) do
      {
        "quotes" => [{ "symbol" => "MSFT", "shortname" => "Microsoft" }],
        "news" => [{ "title" => "Microsoft news", "publisher" => "Example" }]
      }
    end
    @transport.route(%r{/xhr/ncp}) { news_fixture }
    @client = Ryfinance::Client.new(transport: @transport)
    @ticker = Ryfinance::Ticker.new("msft", client: @client)
  end

  def test_history_parses_and_auto_adjusts_rows
    table = @ticker.history(period: "1mo", rounding: true)

    assert_equal 2, table.size
    assert_equal :open, table.columns[1]
    assert_equal 49.5, table.first[:open]
    assert_equal 50.0, table.first[:close]
    assert_equal 0.5, table.first[:dividends]
    assert_equal 2.0, table.last[:stock_splits]
    assert_equal "MSFT", table.metadata[:symbol]
  end

  def test_history_accepts_start_and_end_keyword
    @ticker.history(start: "2024-01-01", end: "2024-01-03")

    query = URI.decode_www_form(@transport.requests.last[:uri].query).to_h
    assert_equal "1704067200", query["period1"]
    assert_equal "1704240000", query["period2"]
  end

  def test_history_accepts_proxy_keyword
    @ticker.history(period: "1mo", proxy: "http://proxy.example:8080")

    assert_equal "http://proxy.example:8080", @transport.requests.last[:proxy]
  end

  def test_history_returns_empty_table_on_yahoo_error_by_default
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { history_error_fixture }
    ticker = Ryfinance::Ticker.new("fail", client: Ryfinance::Client.new(transport: transport))

    table = ticker.history(period: "1mo")

    assert_instance_of Ryfinance::Table, table
    assert_empty table
    assert_equal "FAIL", table.metadata[:symbol]
    assert_instance_of Ryfinance::NotFoundError, table.metadata[:error]
    assert_equal "Ryfinance::NotFoundError", table.metadata[:error_class]
    assert_match(/No data found/, table.metadata[:error_message])
    assert_same table.metadata, ticker.history_metadata
  end

  def test_history_can_raise_yahoo_errors
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { history_error_fixture }
    ticker = Ryfinance::Ticker.new("fail", client: Ryfinance::Client.new(transport: transport))

    error = assert_raises(Ryfinance::NotFoundError) do
      ticker.history(period: "1mo", raise_errors: true)
    end

    assert_match(/No data found/, error.message)
  end

  def test_history_still_raises_local_validation_errors
    assert_raises(ArgumentError) { @ticker.history(period: "900y") }
    assert_raises(ArgumentError) { @ticker.history(interval: "17m") }
  end

  def test_history_repair_fixes_100x_currency_unit_mixups
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { unit_mixup_chart_fixture }
    ticker = Ryfinance::Ticker.new("aet.l", client: Ryfinance::Client.new(transport: transport))

    table = ticker.history(period: "1mo", auto_adjust: false, repair: true)

    assert_equal 111.0, table[1][:close]
    assert_equal 112.0, table[1][:high]
    assert table[1][:repaired]
    assert_equal :currency_unit, table[1][:repair_actions].first[:type]
    assert_equal 0.01, table[1][:repair_actions].first[:factor]
    assert_equal 1, table.metadata[:repairs].count { |repair| repair[:type] == :currency_unit }
  end

  def test_history_repair_interpolates_missing_prices_with_volume
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { missing_price_chart_fixture }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    table = ticker.history(period: "1mo", auto_adjust: false, repair: true)

    assert_equal 106.0, table[1][:close]
    assert_equal 106.0, table[1][:adj_close]
    assert table[1][:repaired]
    assert_equal :missing_price, table[1][:repair_actions].first[:type]
  end

  def test_history_repair_reconstructs_missing_prices_from_fine_interval_data
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) do |uri|
      query = URI.decode_www_form(uri.query.to_s).to_h
      query["interval"] == "1h" ? fine_interval_reconstruction_fixture : missing_opening_price_chart_fixture
    end
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    table = ticker.history(period: "1mo", auto_adjust: false, repair: true)

    assert_equal 99.0, table.first[:open]
    assert_equal 102.0, table.first[:high]
    assert_equal 98.0, table.first[:low]
    assert_equal 101.0, table.first[:close]
    assert_equal 450, table.first[:volume]
    assert table.first[:repaired]
    assert_equal :missing_price_reconstruction, table.first[:repair_actions].first[:type]
  end

  def test_history_repair_fixes_ohlc_bounds_and_action_unit_mixups
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { ohlc_and_action_repair_fixture }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    table = ticker.history(period: "1mo", auto_adjust: false, repair: true)

    assert_equal 105.0, table.first[:high]
    assert_equal 95.0, table.first[:low]
    assert_equal 1.0, table.first[:dividends]
    assert table.first[:repaired]
    assert_includes table.first[:repair_actions].map { |repair| repair[:type] }, :ohlc_bounds
    assert_includes table.first[:repair_actions].map { |repair| repair[:type] }, :action_currency_unit
  end

  def test_history_repair_fixes_missing_dividend_adjustment
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { missing_dividend_adjustment_fixture }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    table = ticker.history(period: "1mo", auto_adjust: false, repair: true)

    assert_equal 99.0, table.first[:adj_close]
    assert table.first[:repaired]
    assert_equal :dividend_adjustment, table.first[:repair_actions].first[:type]
  end

  def test_history_repair_fixes_missing_capital_gain_adjustment
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { missing_capital_gain_adjustment_fixture }
    ticker = Ryfinance::Ticker.new("fund", client: Ryfinance::Client.new(transport: transport))

    table = ticker.history(period: "1mo", auto_adjust: false, repair: true)

    assert_equal 98.0, table.first[:adj_close]
    assert table.first[:repaired]
    assert_equal :capital_gain_adjustment, table.first[:repair_actions].first[:type]
  end

  def test_history_repair_fixes_small_action_unit_mixups_before_adjusting_dividends
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { small_dividend_unit_mixup_fixture }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    table = ticker.history(period: "1mo", auto_adjust: false, repair: true)

    assert_equal 1.0, table[1][:dividends]
    assert_equal 99.0, table.first[:adj_close]
    assert_includes table[1][:repair_actions].map { |repair| repair[:type] }, :action_currency_unit
  end

  def test_history_repair_fixes_bad_split_adjustment
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { bad_split_adjustment_fixture }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    table = ticker.history(period: "1mo", auto_adjust: false, repair: true)

    assert_equal 100.0, table.first[:close]
    assert_equal 2000.0, table.first[:volume]
    assert table.first[:repaired]
    assert_equal :split_adjustment, table.first[:repair_actions].first[:type]
  end

  def test_actions_helpers_return_filtered_tables
    dividends = @ticker.dividends
    splits = @ticker.splits

    assert_equal 1, dividends.size
    assert_equal 0.5, dividends.first[:dividend]
    assert_equal 1, splits.size
    assert_equal 2.0, splits.first[:stock_split]
  end

  def test_info_and_fast_info
    info = @ticker.info
    fast_info = @ticker.fast_info

    assert_equal "Microsoft Corporation", info[:long_name]
    assert_equal 450.0, info[:target_mean_price]
    assert_equal 420.25, fast_info[:last_price]
    assert_equal 418.0, fast_info[:previous_close]
  end

  def test_valuation_measures_return_snapshot_table
    valuation = @ticker.valuation

    assert_instance_of Ryfinance::Table, valuation
    assert_equal %i[metric value source], valuation.columns
    assert_equal 16, valuation.size
    assert_equal "Market Cap", valuation.first[:metric]
    assert_equal 3_000_000_000, valuation.first[:value]
    assert_equal :price, valuation.first[:source]

    enterprise_to_ebitda = valuation.find { |row| row[:metric] == "Enterprise/EBITDA" }
    assert_equal 22.0, enterprise_to_ebitda[:value]
    assert_equal :default_key_statistics, enterprise_to_ebitda[:source]
  end

  def test_valuation_measures_can_return_row_hashes
    rows = @ticker.get_valuation_measures(as_dict: true)

    assert_instance_of Array, rows
    assert_equal "Market Cap", rows.first[:metric]
  end

  def test_analyst_price_targets_and_recommendations
    targets = @ticker.analyst_price_targets
    recommendations = @ticker.recommendations

    assert_equal 450.0, targets[:mean]
    assert_equal 1, recommendations.size
    assert_equal "0m", recommendations.first[:period]
  end

  def test_options_and_option_chain
    assert_equal ["2024-01-02"], @ticker.options

    chain = @ticker.option_chain("2024-01-02")

    assert_equal 1, chain.calls.size
    assert_equal "MSFT240102C00420000", chain.calls.first[:contract_symbol]
    assert_equal "MSFT", chain.underlying[:symbol]
  end

  def test_news_and_search
    search = Ryfinance.search("msft", client: @client, quotes_count: 1, news_count: 1)

    assert_equal "MSFT", search.quotes.first[:symbol]
    assert_equal "Microsoft news", @ticker.news(count: 1).first[:title]
  end

  def test_news_uses_yahoo_ncp_tabs_and_filters_ads
    articles = @ticker.news(count: 3, tab: "press releases")

    assert_equal 1, articles.size
    assert_equal "Microsoft news", articles.first[:title]
    request = @transport.requests.last
    query = URI.decode_www_form(request[:uri].query).to_h
    assert_equal "pressRelease", query["queryRef"]
    assert_equal "ncp_fin", query["serviceKey"]
    assert_equal 3, request[:body].dig("serviceConfig", "snippetCount")
    assert_equal ["MSFT"], request[:body].dig("serviceConfig", "s")
  end

  def test_news_rejects_unknown_tabs
    assert_raises(ArgumentError) { @ticker.news(tab: "videos") }
  end

  def test_shares_full_is_ruby_alias_for_get_shares_full
    shares = @ticker.shares_full(start: "2024-01-01", end: "2024-01-02")

    assert_equal [:date, :shares], shares.columns
    assert_equal 7_430_000_000, shares.first[:shares]
  end

  def test_shares_alias_returns_table_and_date_indexed_hash
    shares = @ticker.shares(start: "2024-01-01", end: "2024-01-02")
    as_dict = @ticker.get_shares(start: "2024-01-01", end: "2024-01-02", as_dict: true)

    assert_equal [:date, :shares], shares.columns
    assert_equal 7_430_000_000, shares.first[:shares]
    assert_equal({ shares: 7_430_000_000 }, as_dict.fetch(Time.utc(2024, 1, 1)))

    query = URI.decode_www_form(@transport.requests.last[:uri].query).to_h
    assert_equal "shares_out", query["type"]
    assert_equal "1704067200", query["period1"]
    assert_equal "1704153600", query["period2"]
  end

  def test_ruby_first_financial_statement_aliases_are_public
    assert @ticker.respond_to?(:income_statement)
    assert @ticker.respond_to?(:quarterly_income_statement)
    assert @ticker.respond_to?(:ttm_income_statement)
  end

  def test_financial_statements_use_fundamentals_timeseries
    transport = FakeTransport.new
    transport.route(%r{/ws/fundamentals-timeseries/v1/finance/timeseries/}) { financial_statement_timeseries_fixture }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    statement = ticker.income_statement

    assert_equal %i[end_date total_revenue net_income], statement.columns
    assert_equal Time.utc(2023, 12, 31), statement.first[:end_date]
    assert_equal 211_915_000_000, statement.first[:total_revenue]
    assert_equal 72_361_000_000, statement.first[:net_income]
    assert_equal :timeseries, statement.metadata[:source]
    query = URI.decode_www_form(transport.requests.last[:uri].query).to_h
    assert_includes query["type"], "annualTotalRevenue"
    assert_includes query["type"], "annualNetIncome"
  end

  def test_financial_statements_support_quarterly_and_trailing_timescales
    transport = FakeTransport.new
    transport.route(%r{/ws/fundamentals-timeseries/v1/finance/timeseries/}) { financial_statement_timeseries_fixture(prefix: "quarterly") }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    ticker.quarterly_income_statement

    query = URI.decode_www_form(transport.requests.last[:uri].query).to_h
    assert_includes query["type"], "quarterlyTotalRevenue"

    transport = FakeTransport.new
    transport.route(%r{/ws/fundamentals-timeseries/v1/finance/timeseries/}) { financial_statement_timeseries_fixture(prefix: "trailing") }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    ticker.ttm_cash_flow

    query = URI.decode_www_form(transport.requests.last[:uri].query).to_h
    assert_includes query["type"], "trailingFreeCashFlow"
  end

  def test_balance_sheet_rejects_trailing_timescale
    assert_raises(ArgumentError) { @ticker.balance_sheet(freq: "trailing") }
  end

  def test_earnings_dates_parses_visualization_response
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/visualization}) { earnings_dates_fixture }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    dates = ticker.earnings_dates(limit: 2, offset: 1)

    assert_instance_of Ryfinance::Table, dates
    assert_equal %i[earnings_date eps_estimate reported_eps surprise_percent event_type timezone_short_name], dates.columns
    assert_equal Time.utc(2026, 4, 23, 20), dates.first[:earnings_date]
    assert_equal 3.2, dates.first[:eps_estimate]
    assert_equal 3.5, dates.first[:reported_eps]
    assert_equal 9.4, dates.first[:surprise_percent]
    assert_equal "Earnings", dates.first[:event_type]
    assert_equal "EDT", dates.first[:timezone_short_name]
    assert_nil dates.last[:reported_eps]
    assert_equal "Call", dates.last[:event_type]
  end

  def test_earnings_dates_sends_limit_and_offset
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/visualization}) { earnings_dates_fixture }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    ticker.get_earnings_dates(limit: 7, offset: 14)

    request = transport.requests.last
    assert_equal :post, request[:method]
    assert_equal 7, request[:body]["size"]
    assert_equal 14, request[:body]["offset"]
    assert_equal ["ticker", "MSFT"], request[:body].dig("query", "operands")
  end

  def test_earnings_dates_can_return_row_hashes
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/visualization}) { earnings_dates_fixture }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    rows = ticker.get_earnings_dates(as_dict: true)

    assert_instance_of Array, rows
    assert_equal "Earnings", rows.first[:event_type]
  end

  def test_earnings_dates_returns_nil_when_yahoo_has_no_rows
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/visualization}) { earnings_dates_fixture(rows: []) }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    assert_nil ticker.earnings_dates
  end

  def test_earnings_dates_validates_limit_and_offset
    assert_raises(ArgumentError) { @ticker.earnings_dates(limit: 101) }
    assert_raises(ArgumentError) { @ticker.earnings_dates(offset: -1) }
  end

  private

  def history_error_fixture
    {
      "chart" => {
        "result" => nil,
        "error" => {
          "code" => "Not Found",
          "description" => "No data found for FAIL"
        }
      }
    }
  end

  def financial_statement_timeseries_fixture(prefix: "annual")
    {
      "timeseries" => {
        "result" => [
          {
            "meta" => { "type" => ["#{prefix}TotalRevenue"] },
            "timestamp" => [1_672_444_800, 1_704_067_200],
            "#{prefix}TotalRevenue" => [
              { "asOfDate" => "2022-12-31", "reportedValue" => { "raw" => 198_270_000_000 } },
              { "asOfDate" => "2023-12-31", "reportedValue" => { "raw" => 211_915_000_000 } }
            ]
          },
          {
            "meta" => { "type" => ["#{prefix}NetIncome"] },
            "timestamp" => [1_672_444_800, 1_704_067_200],
            "#{prefix}NetIncome" => [
              { "asOfDate" => "2022-12-31", "reportedValue" => { "raw" => 72_738_000_000 } },
              { "asOfDate" => "2023-12-31", "reportedValue" => { "raw" => 72_361_000_000 } }
            ]
          },
          {
            "meta" => { "type" => ["#{prefix}FreeCashFlow"] },
            "timestamp" => [1_704_067_200],
            "#{prefix}FreeCashFlow" => [
              { "asOfDate" => "2023-12-31", "reportedValue" => { "raw" => 59_475_000_000 } }
            ]
          }
        ]
      }
    }
  end

  def unit_mixup_chart_fixture
    chart_fixture_with(
      open: [99.0, 11_000.0, 111.0],
      high: [101.0, 11_200.0, 113.0],
      low: [98.0, 10_900.0, 110.0],
      close: [100.0, 11_100.0, 112.0],
      adjclose: [100.0, 11_100.0, 112.0],
      volume: [1000, 1200, 1400]
    )
  end

  def missing_price_chart_fixture
    chart_fixture_with(
      open: [99.0, nil, 111.0],
      high: [101.0, nil, 113.0],
      low: [98.0, nil, 110.0],
      close: [100.0, 0.0, 112.0],
      adjclose: [100.0, 0.0, 112.0],
      volume: [1000, 1200, 1400]
    )
  end

  def missing_opening_price_chart_fixture
    chart_fixture_with(
      open: [nil, 110.0, 111.0],
      high: [nil, 112.0, 113.0],
      low: [nil, 109.0, 110.0],
      close: [0.0, 111.0, 112.0],
      adjclose: [0.0, 111.0, 112.0],
      volume: [450, 1500, 1400]
    )
  end

  def fine_interval_reconstruction_fixture
    {
      "chart" => {
        "result" => [
          {
            "meta" => {
              "symbol" => "MSFT",
              "currency" => "USD",
              "exchangeTimezoneName" => "America/New_York"
            },
            "timestamp" => [1_704_067_200, 1_704_070_800, 1_704_074_400],
            "indicators" => {
              "quote" => [
                {
                  "open" => [99.0, 100.0, 100.5],
                  "high" => [100.5, 102.0, 101.5],
                  "low" => [98.0, 99.5, 100.0],
                  "close" => [100.0, 100.5, 101.0],
                  "volume" => [100, 150, 200]
                }
              ],
              "adjclose" => [
                { "adjclose" => [100.0, 100.5, 101.0] }
              ]
            }
          }
        ],
        "error" => nil
      }
    }
  end

  def ohlc_and_action_repair_fixture
    chart_fixture_with(
      open: [100.0, 102.0, 104.0],
      high: [95.0, 103.0, 105.0],
      low: [105.0, 101.0, 103.0],
      close: [102.0, 102.5, 104.5],
      adjclose: [102.0, 102.5, 104.5],
      volume: [1000, 1200, 1400],
      events: {
        "dividends" => {
          "1704067200" => { "date" => 1_704_067_200, "amount" => 100.0 }
        }
      }
    )
  end

  def missing_dividend_adjustment_fixture
    chart_fixture_with(
      open: [99.0, 99.0, 101.0],
      high: [101.0, 100.0, 102.0],
      low: [98.0, 98.0, 100.0],
      close: [100.0, 99.0, 101.0],
      adjclose: [100.0, 99.0, 101.0],
      volume: [1000, 1200, 1400],
      events: {
        "dividends" => {
          "1704153600" => { "date" => 1_704_153_600, "amount" => 1.0 }
        }
      }
    )
  end

  def missing_capital_gain_adjustment_fixture
    chart_fixture_with(
      open: [99.0, 100.0, 101.0],
      high: [101.0, 102.0, 103.0],
      low: [98.0, 99.0, 100.0],
      close: [100.0, 100.0, 102.0],
      adjclose: [100.0, 100.0, 102.0],
      volume: [1000, 1200, 1400],
      events: {
        "capitalGains" => {
          "1704153600" => { "date" => 1_704_153_600, "amount" => 2.0 }
        }
      }
    )
  end

  def small_dividend_unit_mixup_fixture
    chart_fixture_with(
      open: [99.0, 99.0, 101.0],
      high: [101.0, 100.0, 102.0],
      low: [98.0, 98.0, 100.0],
      close: [100.0, 99.0, 101.0],
      adjclose: [100.0, 99.0, 101.0],
      volume: [1000, 1200, 1400],
      events: {
        "dividends" => {
          "1704153600" => { "date" => 1_704_153_600, "amount" => 0.01 }
        }
      }
    )
  end

  def bad_split_adjustment_fixture
    chart_fixture_with(
      open: [198.0, 99.0, 101.0],
      high: [202.0, 101.0, 103.0],
      low: [196.0, 98.0, 100.0],
      close: [200.0, 100.0, 102.0],
      adjclose: [200.0, 100.0, 102.0],
      volume: [1000, 1200, 1400],
      events: {
        "splits" => {
          "1704153600" => {
            "date" => 1_704_153_600,
            "numerator" => 2,
            "denominator" => 1,
            "splitRatio" => "2:1"
          }
        }
      }
    )
  end

  def chart_fixture_with(open:, high:, low:, close:, adjclose:, volume:, events: {})
    timestamps = [1_704_067_200, 1_704_153_600, 1_704_240_000]
    {
      "chart" => {
        "result" => [
          {
            "meta" => {
              "symbol" => "MSFT",
              "currency" => "USD",
              "exchangeTimezoneName" => "America/New_York"
            },
            "timestamp" => timestamps,
            "indicators" => {
              "quote" => [
                {
                  "open" => open,
                  "high" => high,
                  "low" => low,
                  "close" => close,
                  "volume" => volume
                }
              ],
              "adjclose" => [
                { "adjclose" => adjclose }
              ]
            },
            "events" => events
          }
        ],
        "error" => nil
      }
    }
  end
end
