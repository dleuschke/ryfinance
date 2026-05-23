# frozen_string_literal: true

require_relative "test_helper"

class ScreenerTest < Minitest::Test
  def test_query_serializes_yahoo_shape
    query = Ryfinance::EquityQuery.new("and", [
      Ryfinance::EquityQuery.new("gt", ["percentchange", 3]),
      Ryfinance::EquityQuery.new("eq", ["region", "us"])
    ])

    assert_equal(
      {
        "operator" => "AND",
        "operands" => [
          { "operator" => "GT", "operands" => ["percentchange", 3] },
          { "operator" => "EQ", "operands" => ["region", "us"] }
        ]
      },
      query.to_h
    )
  end

  def test_query_validates_shape
    assert_raises(ArgumentError) do
      Ryfinance::EquityQuery.new("and", ["not a query"])
    end

    assert_raises(ArgumentError) do
      Ryfinance::EquityQuery.new("and", [
        Ryfinance::EquityQuery.new("gt", ["percentchange", 3])
      ])
    end

    assert_raises(ArgumentError) do
      Ryfinance::EquityQuery.new("btwn", ["intradayprice", 10])
    end
  end

  def test_query_validates_fields_values_and_numeric_operands
    assert_raises(ArgumentError) do
      Ryfinance::EquityQuery.new("gt", ["definitely_not_a_yahoo_field", 3])
    end

    assert_raises(ArgumentError) do
      Ryfinance::EquityQuery.new("gt", ["percentchange", "3"])
    end

    assert_raises(ArgumentError) do
      Ryfinance::EquityQuery.new("eq", ["region", "mars"])
    end

    assert_raises(ArgumentError) do
      Ryfinance::EquityQuery.new("is-in", ["exchange", "NMS", "NOPE"])
    end
  end

  def test_query_normalizes_symbol_fields_and_enum_values
    query = Ryfinance::EquityQuery.new("eq", [:region, :us])

    assert_equal({ "operator" => "EQ", "operands" => ["region", "us"] }, query.to_h)
  end

  def test_is_in_serializes_as_or_of_eq_queries
    query = Ryfinance::EquityQuery.new("is-in", ["exchange", "NMS", "NYQ"])

    assert_equal(
      {
        "operator" => "OR",
        "operands" => [
          { "operator" => "EQ", "operands" => ["exchange", "NMS"] },
          { "operator" => "EQ", "operands" => ["exchange", "NYQ"] }
        ]
      },
      query.to_h
    )
  end

  def test_query_metadata_includes_broader_yfinance_fields
    assert_includes Ryfinance::EquityQuery.valid_fields[:cash_flow], "leveredfreecashflow.lasttwelvemonths"
    assert_includes Ryfinance::EquityQuery.valid_fields[:short_interest], "days_to_cover_short.value"
    assert_includes Ryfinance::FundQuery.valid_fields[:price], "intradaypricechange"
    assert_includes Ryfinance::ETFQuery.valid_fields[:eq_fields], "morningstar_uncertainty"
    assert_includes Ryfinance::ETFQuery.valid_values[:morningstar_uncertainty], "Very High"
  end

  def test_large_open_enum_fields_do_not_reject_valid_yahoo_values
    equity = Ryfinance::EquityQuery.new("eq", ["industry", "Semiconductors"])
    fund = Ryfinance::FundQuery.new("eq", ["categoryname", "Large Blend"])
    etf = Ryfinance::ETFQuery.new("eq", ["fundfamilyname", "iShares"])

    assert_equal ["industry", "Semiconductors"], equity.to_h["operands"]
    assert_equal ["categoryname", "Large Blend"], fund.to_h["operands"]
    assert_equal ["fundfamilyname", "iShares"], etf.to_h["operands"]
    assert_includes Ryfinance::ETFQuery.restricted_value_fields, "morningstar_uncertainty"
    assert_includes Ryfinance::ETFQuery.unrestricted_value_fields, "fundfamilyname"
  end

  def test_predefined_screen_uses_predefined_endpoint
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/screener/predefined/saved}) { screener_fixture }
    client = Ryfinance::Client.new(transport: transport)

    result = Ryfinance.screen("day_gainers", client: client, count: 5)

    assert_equal "MSFT", result[:quotes].first[:symbol]
    query = URI.decode_www_form(transport.requests.last[:uri].query).to_h
    assert_equal "day_gainers", query["scrIds"]
    assert_equal "5", query["count"]
  end

  def test_custom_screen_posts_query_body
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/screener$}) { screener_fixture }
    client = Ryfinance::Client.new(transport: transport)
    query = Ryfinance::EquityQuery.new("gt", ["percentchange", 3])

    Ryfinance.screen(query, client: client, sort_field: "percentchange", sort_asc: true)

    body = transport.requests.last.fetch(:body)
    assert_equal "EQUITY", body["quoteType"]
    assert_equal "ASC", body["sortType"]
    assert_equal({ "operator" => "GT", "operands" => ["percentchange", 3] }, body["query"])
  end

  def test_predefined_screen_with_offset_posts_custom_body
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/screener$}) { screener_fixture }
    client = Ryfinance::Client.new(transport: transport)

    Ryfinance.screen("day_gainers", client: client, offset: 25)

    body = transport.requests.last.fetch(:body)
    assert_equal 25, body["offset"]
    assert_equal "percentchange", body["sortField"]
    assert_equal "DESC", body["sortType"]
  end
end
