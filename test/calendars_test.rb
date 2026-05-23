# frozen_string_literal: true

require_relative "test_helper"

class CalendarsTest < Minitest::Test
  def setup
    @transport = FakeTransport.new
    @transport.route(%r{/v1/finance/visualization}) { calendar_fixture }
    @client = Ryfinance::Client.new(transport: @transport)
    @calendars = Ryfinance::Calendars.new(start: "2026-04-01", end: "2026-04-30", client: @client)
  end

  def test_top_level_constructors_return_calendars
    assert_instance_of Ryfinance::Calendars, Ryfinance.calendars(start: "2026-04-01", client: @client)
    assert_instance_of Ryfinance::Calendars, Ryfinance.Calendars(start: "2026-04-01", client: @client)
  end

  def test_earnings_calendar_posts_yahoo_visualization_query
    table = @calendars.get_earnings_calendar(limit: 5, filter_most_active: false)

    assert_instance_of Ryfinance::Table, table
    assert_equal %i[symbol company market_cap event_name event_start_date timing eps_estimate reported_eps surprise_percent], table.columns
    assert_equal "MSFT", table.first[:symbol]
    assert_equal Time.utc(2026, 4, 23, 20), table.first[:event_start_date]
    assert_equal "After Market Close", table.first[:timing]
    assert_equal 3.2, table.first[:eps_estimate]
    assert_nil table.last[:reported_eps]

    request = @transport.requests.last
    assert_equal :post, request[:method]
    assert_equal "sp_earnings", request[:body]["entityIdType"]
    assert_equal "intradaymarketcap", request[:body]["sortField"]
    assert_equal 5, request[:body]["size"]
    assert_equal "AND", request[:body].dig("query", "operator")
    assert_includes request[:body].dig("query", "operands"), { "operator" => "GTE", "operands" => ["startdatetime", "2026-04-01"] }
    assert_includes request[:body].dig("query", "operands"), { "operator" => "LTE", "operands" => ["startdatetime", "2026-04-30"] }
  end

  def test_earnings_calendar_can_filter_to_most_active_tickers
    @transport.route(%r{/v1/finance/screener/predefined/saved}) { screener_fixture }

    @calendars.get_earnings_calendar(filter_most_active: true)

    body = @transport.requests.last[:body]
    most_active = body.dig("query", "operands").find do |operand|
      operand["operator"] == "OR" && operand["operands"].any? { |nested| nested["operands"] == ["ticker", "MSFT"] }
    end
    refute_nil most_active
  end

  def test_ipo_calendar_uses_date_range_across_ipo_date_fields
    @calendars.get_ipo_info_calendar(offset: 2)

    body = @transport.requests.last[:body]
    assert_equal "ipo_info", body["entityIdType"]
    assert_equal 2, body["offset"]
    assert_equal(
      [
        { "operator" => "GTELT", "operands" => ["startdatetime", "2026-04-01", "2026-04-30"] },
        { "operator" => "GTELT", "operands" => ["filingdate", "2026-04-01", "2026-04-30"] },
        { "operator" => "GTELT", "operands" => ["amendeddate", "2026-04-01", "2026-04-30"] }
      ],
      body.dig("query", "operands")
    )
  end

  def test_economic_events_calendar_uses_economic_entity_type
    @calendars.economic_events_calendar

    body = @transport.requests.last[:body]
    assert_equal "economic_event", body["entityIdType"]
    assert_equal "startdatetime", body["sortField"]
  end

  def test_splits_calendar_uses_splits_entity_type
    @calendars.splits_calendar

    body = @transport.requests.last[:body]
    assert_equal "splits", body["entityIdType"]
    assert_includes body["includeFields"], "old_share_worth"
  end

  def test_repeated_calendar_call_uses_cache
    first = @calendars.get_earnings_calendar(filter_most_active: false)
    second = @calendars.get_earnings_calendar(filter_most_active: false)

    assert_equal first.to_a, second.to_a
    assert_equal 1, @transport.requests.size
  end

  def test_force_bypasses_cache
    @calendars.get_earnings_calendar(filter_most_active: false)
    @calendars.get_earnings_calendar(filter_most_active: false, force: true)

    assert_equal 2, @transport.requests.size
  end

  def test_limit_and_offset_are_validated
    assert_raises(ArgumentError) { @calendars.earnings_calendar(limit: 0) }
    assert_raises(ArgumentError) { @calendars.earnings_calendar(offset: -1) }
  end
end
