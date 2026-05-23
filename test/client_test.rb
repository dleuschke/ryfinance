# frozen_string_literal: true

require_relative "test_helper"

class ClientTest < Minitest::Test
  def test_chart_raises_yahoo_error
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/NOPE}) do
      { "chart" => { "result" => nil, "error" => { "code" => "Not Found", "description" => "No data" } } }
    end
    client = Ryfinance::Client.new(transport: transport)

    assert_raises(Ryfinance::NotFoundError) do
      client.chart("NOPE", params: { range: "1d", interval: "1d" })
    end
  end

  def test_search_passes_counts
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/search}) { { "quotes" => [], "news" => [] } }
    client = Ryfinance::Client.new(transport: transport)

    client.search("msft", quotes_count: 3, news_count: 2)

    query = URI.decode_www_form(transport.requests.last[:uri].query).to_h
    assert_equal "3", query["quotesCount"]
    assert_equal "2", query["newsCount"]
  end

  def test_get_retries_with_cookie_crumb_on_forbidden_response
    transport = FakeTransport.new
    transport.route(%r{\Ahttps://fc\.yahoo\.com}) { { code: 204, body: "" } }
    transport.route(%r{/v1/test/getcrumb}) { { code: 200, body: "crumb-token" } }
    transport.route(%r{/v7/finance/quote}) do |uri|
      query = URI.decode_www_form(uri.query.to_s).to_h
      if query["crumb"] == "crumb-token"
        quote_fixture
      else
        { code: 403, body: "Forbidden" }
      end
    end
    client = Ryfinance::Client.new(transport: transport)

    result = client.quote("MSFT")

    assert_equal "MSFT", result.first["symbol"]
    quote_requests = transport.requests.select { |request| request[:uri].path == "/v7/finance/quote" }
    assert_equal 2, quote_requests.size
    refute_includes URI.decode_www_form(quote_requests.first[:uri].query.to_s).to_h, "crumb"
    assert_equal "crumb-token", URI.decode_www_form(quote_requests.last[:uri].query.to_s).to_h["crumb"]
  end

  def test_crumb_can_be_disabled
    transport = FakeTransport.new
    transport.route(%r{/v7/finance/quote}) { { code: 403, body: "Forbidden" } }
    client = Ryfinance::Client.new(transport: transport, crumb: false)

    assert_raises(Ryfinance::HTTPError) do
      client.quote("MSFT")
    end

    assert_equal 1, transport.requests.size
  end

  def test_crumb_always_attaches_crumb_to_first_request
    transport = FakeTransport.new
    transport.route(%r{\Ahttps://fc\.yahoo\.com}) { { code: 204, body: "" } }
    transport.route(%r{/v1/test/getcrumb}) { { code: 200, body: "crumb-token" } }
    transport.route(%r{/v7/finance/quote}) { quote_fixture }
    client = Ryfinance::Client.new(transport: transport, crumb: :always)

    client.quote("MSFT")

    query = URI.decode_www_form(transport.requests.last[:uri].query.to_s).to_h
    assert_equal "crumb-token", query["crumb"]
  end

  def test_client_caches_successful_get_responses
    transport = FakeTransport.new
    calls = 0
    transport.route(%r{/v7/finance/quote}) do
      calls += 1
      quote_fixture("MSFT")
    end
    client = Ryfinance::Client.new(transport: transport, cache: true, cache_ttl: 60)

    first = client.quote("MSFT")
    second = client.quote("MSFT")

    assert_equal "MSFT", first.first["symbol"]
    assert_equal first, second
    assert_equal 1, calls
    assert_equal 1, transport.requests.size
  end

  def test_client_clear_cache_forces_next_get
    transport = FakeTransport.new
    calls = 0
    transport.route(%r{/v7/finance/quote}) do
      calls += 1
      quote_fixture("MSFT")
    end
    client = Ryfinance::Client.new(transport: transport, cache: Ryfinance::MemoryCache.new, cache_ttl: 60)

    client.quote("MSFT")
    client.clear_cache
    client.quote("MSFT")

    assert_equal 2, calls
  end

  def test_transient_responses_are_retried
    transport = FakeTransport.new
    attempts = 0
    transport.route(%r{/v7/finance/quote}) do
      attempts += 1
      attempts == 1 ? { code: 503, body: "try later" } : quote_fixture("MSFT")
    end
    client = Ryfinance::Client.new(transport: transport, retries: 1, retry_backoff: 0)

    result = client.quote("MSFT")

    assert_equal "MSFT", result.first["symbol"]
    assert_equal 2, attempts
  end

  def test_retry_after_header_is_accepted
    transport = FakeTransport.new
    attempts = 0
    transport.route(%r{/v7/finance/quote}) do
      attempts += 1
      if attempts == 1
        { code: 429, body: "rate limited", headers: { "Retry-After" => "0" } }
      else
        quote_fixture("MSFT")
      end
    end
    client = Ryfinance::Client.new(transport: transport, retries: 1, retry_backoff: 30)

    result = client.quote("MSFT")

    assert_equal "MSFT", result.first["symbol"]
    assert_equal 2, attempts
  end
end
