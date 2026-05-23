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
end

