# frozen_string_literal: true

require_relative "test_helper"

class TickerTest < Minitest::Test
  def setup
    @transport = FakeTransport.new
    @transport.route(%r{/v8/finance/chart/}) { chart_fixture }
    @transport.route(%r{/v7/finance/quote}) { quote_fixture }
    @transport.route(%r{/v10/finance/quoteSummary/}) { quote_summary_fixture }
    @transport.route(%r{/v7/finance/options/}) { options_fixture }
    @transport.route(%r{/v1/finance/search}) do
      {
        "quotes" => [{ "symbol" => "MSFT", "shortname" => "Microsoft" }],
        "news" => [{ "title" => "Microsoft news", "publisher" => "Example" }]
      }
    end
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
end
