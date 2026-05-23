# frozen_string_literal: true

require_relative "test_helper"

class FundsDataTest < Minitest::Test
  def setup
    @transport = FakeTransport.new
    @transport.route(%r{/v10/finance/quoteSummary/}) { fund_quote_summary_fixture }
    @client = Ryfinance::Client.new(transport: @transport)
    @ticker = Ryfinance::Ticker.new("vti", client: @client)
  end

  def test_ticker_exposes_funds_data_for_etfs_and_mutual_funds
    funds_data = @ticker.funds_data

    assert_instance_of Ryfinance::FundsData, funds_data
    assert_equal "ETF", funds_data.quote_type
    assert funds_data.fund?
  end

  def test_funds_data_parses_top_holdings_and_allocations
    funds_data = @ticker.funds_data

    assert_equal "A total stock market ETF.", funds_data.description
    assert_equal "Vanguard", funds_data.fund_overview[:family]
    assert_equal "Large Blend", funds_data.fund_overview[:category_name]
    assert_equal 0.95, funds_data.asset_classes[:stock_position]
    assert_equal 0.28, funds_data.sector_weightings[:technology]
    assert_equal 0.2, funds_data.bond_ratings[:us_government]

    holding = funds_data.top_holdings.first
    assert_equal "AAPL", holding[:symbol]
    assert_equal "Apple Inc.", holding[:name]
    assert_equal 0.064, holding[:holding_percent]
  end

  def test_funds_data_returns_tables_for_peer_comparisons
    funds_data = @ticker.funds_data

    assert_equal %i[metric value category_average], funds_data.equity_holdings.columns
    assert_equal "Price/Earnings", funds_data.equity_holdings.first[:metric]
    assert_equal 21.1, funds_data.equity_holdings.first[:value]
    assert_equal 22.2, funds_data.equity_holdings.first[:category_average]

    assert_equal "Duration", funds_data.bond_holdings[1][:metric]
    assert_equal 5.2, funds_data.bond_holdings[1][:value]

    assert_equal "Annual Report Expense Ratio", funds_data.fund_operations.first[:metric]
    assert_equal 0.0003, funds_data.fund_operations.first[:value]
    assert_equal 0.005, funds_data.fund_operations.first[:category_average]
  end

  def test_funds_data_to_h_contains_tables_as_arrays
    data = @ticker.funds_data.to_h

    assert_equal "VTI", data[:symbol]
    assert_equal "ETF", data[:quote_type]
    assert_equal "Exchange Traded Fund", data[:fund_overview][:legal_type]
    assert_equal "AAPL", data[:top_holdings].first[:symbol]
    assert_equal 0.3, data[:bond_ratings][:aaa]
  end

  def test_non_fund_tickers_return_nil
    transport = FakeTransport.new
    transport.route(%r{/v10/finance/quoteSummary/}) { stock_quote_summary_fixture }
    ticker = Ryfinance::Ticker.new("msft", client: Ryfinance::Client.new(transport: transport))

    assert_nil ticker.funds_data
  end

  def test_funds_data_is_fetched_once_per_ticker
    funds_data = @ticker.funds_data
    funds_data.top_holdings
    funds_data.asset_classes
    funds_data.sector_weightings

    assert_equal 1, @transport.requests.count { |request| request[:uri].path.match?(%r{/v10/finance/quoteSummary/}) }
  end
end
