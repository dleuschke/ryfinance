# frozen_string_literal: true

require_relative "test_helper"

class LookupTest < Minitest::Test
  def setup
    @transport = FakeTransport.new
    @transport.route(%r{/v1/finance/lookup}) do |uri|
      query = URI.decode_www_form(uri.query).to_h
      symbol = query["type"] == "etf" ? "SPY" : "AAPL"
      quote_type = query["type"] == "etf" ? "ETF" : "EQUITY"
      lookup_fixture(symbol: symbol, quote_type: quote_type)
    end
    @client = Ryfinance::Client.new(transport: @transport)
  end

  def test_module_lookup_returns_lookup_object
    lookup = Ryfinance.lookup("apple", client: @client)

    assert_instance_of Ryfinance::Lookup, lookup
    assert_equal "apple", lookup.query
  end

  def test_capitalized_constructor_returns_lookup_object
    lookup = Ryfinance.Lookup("apple", client: @client)

    assert_instance_of Ryfinance::Lookup, lookup
  end

  def test_lookup_returns_table_for_stocks
    table = Ryfinance::Lookup.new("apple", client: @client).stock

    assert_instance_of Ryfinance::Table, table
    assert_equal "AAPL", table.first[:symbol]
    assert_equal "Apple Inc.", table.first[:short_name]
    assert_equal "EQUITY", table.first[:quote_type]
    assert_equal 190.25, table.first[:regular_market_price]
  end

  def test_lookup_type_and_count_are_sent_to_yahoo
    Ryfinance::Lookup.new("spy", client: @client).get_etf(count: 9)

    params = URI.decode_www_form(@transport.requests.last[:uri].query).to_h
    assert_equal "spy", params["query"]
    assert_equal "etf", params["type"]
    assert_equal "9", params["count"]
    assert_equal "true", params["fetchPricingData"]
    assert_equal "false", params["formatted"]
  end

  def test_lookup_caches_by_type_and_count
    lookup = Ryfinance::Lookup.new("apple", client: @client)

    lookup.get_stock(count: 3)
    lookup.get_stock(count: 3)
    lookup.get_stock(count: 4)

    assert_equal 2, @transport.requests.count { |request| request[:uri].path.match?(%r{/v1/finance/lookup}) }
  end

  def test_all_lookup_methods_are_available
    lookup = Ryfinance::Lookup.new("apple", client: @client)

    assert_instance_of Ryfinance::Table, lookup.all
    assert_instance_of Ryfinance::Table, lookup.get_all(count: 1)
    assert_instance_of Ryfinance::Table, lookup.stock
    assert_instance_of Ryfinance::Table, lookup.mutualfund
    assert_instance_of Ryfinance::Table, lookup.etf
    assert_instance_of Ryfinance::Table, lookup.index
    assert_instance_of Ryfinance::Table, lookup.future
    assert_instance_of Ryfinance::Table, lookup.currency
    assert_instance_of Ryfinance::Table, lookup.cryptocurrency
  end

  def test_lookup_validates_count
    lookup = Ryfinance::Lookup.new("apple", client: @client)

    assert_raises(ArgumentError) { lookup.get_stock(count: 0) }
  end

  def test_lookup_can_suppress_yahoo_errors
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/lookup}) { lookup_error_fixture }
    lookup = Ryfinance::Lookup.new("apple", client: Ryfinance::Client.new(transport: transport), raise_errors: false)

    assert_empty lookup.stock
  end

  def test_lookup_raises_yahoo_errors_by_default
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/lookup}) { lookup_error_fixture }
    lookup = Ryfinance::Lookup.new("apple", client: Ryfinance::Client.new(transport: transport))

    assert_raises(Ryfinance::YahooError) { lookup.stock }
  end
end
