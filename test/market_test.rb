# frozen_string_literal: true

require_relative "test_helper"

class MarketTest < Minitest::Test
  def setup
    @transport = FakeTransport.new
    @transport.route(%r{/v6/finance/quote/marketSummary}) { market_summary_fixture }
    @transport.route(%r{/v6/finance/markettime}) { market_status_fixture }
    @client = Ryfinance::Client.new(transport: @transport)
    @market = Ryfinance::Market.new("us", client: @client)
  end

  def test_market_constructors_accept_yfinance_and_ruby_shapes
    assert_equal "EUROPE", Ryfinance.market("EUROPE", client: @client).market
    assert_equal "GB", Ryfinance.market(region: "GB", client: @client).market
    assert_equal "ASIA", Ryfinance.Market("ASIA", client: @client).market
  end

  def test_status_fetches_and_normalizes_markettime_response
    status = @market.status

    assert_equal "open", status[:status]
    assert_equal "REGULAR", status[:market_state]
    assert_equal Time.new(2026, 5, 22, 9, 30, 0, "-04:00"), status[:open]
    assert_equal Time.new(2026, 5, 22, 16, 0, 0, "-04:00"), status[:close]
    assert_equal "EDT", status[:timezone][:short]
    assert_equal "EDT", status[:tz]
    refute status.key?(:time)
  end

  def test_summary_returns_table_and_is_cached_with_status
    summary = @market.summary
    status = @market.status

    assert_instance_of Ryfinance::Table, summary
    assert_equal({ market: "US" }, summary.metadata)
    assert_equal 2, summary.size
    assert_equal "S&P 500", summary.first[:short_name]
    assert_equal 5320.25, summary.first[:regular_market_price]
    assert_equal "open", status[:status]
    assert_equal 2, @transport.requests.size
  end

  def test_status_and_summary_send_yfinance_market_params
    @market.status

    summary_query = URI.decode_www_form(@transport.requests[0][:uri].query).to_h
    status_query = URI.decode_www_form(@transport.requests[1][:uri].query).to_h

    assert_equal "US", summary_query["market"]
    assert_equal "shortName,regularMarketPrice,regularMarketChange,regularMarketChangePercent", summary_query["fields"]
    assert_equal "false", summary_query["formatted"]
    assert_equal "US", status_query["market"]
    assert_equal "finance", status_query["key"]
    assert_equal "true", status_query["formatted"]
  end

  def test_summary_fetches_market_status_once
    @market.summary
    @market.summary
    @market.status

    assert_equal 2, @transport.requests.size
  end
end
