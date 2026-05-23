# frozen_string_literal: true

require_relative "test_helper"

class DownloadTest < Minitest::Test
  def test_download_returns_table_for_single_ticker_by_default
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { chart_fixture }
    client = Ryfinance::Client.new(transport: transport)

    result = Ryfinance.download("msft", client: client)

    assert_instance_of Ryfinance::Table, result
    assert_equal 2, result.size
  end

  def test_download_combines_multiple_tickers
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { |uri| chart_fixture(uri.path.split("/").last) }
    client = Ryfinance::Client.new(transport: transport)

    result = Ryfinance.download("msft aapl", client: client, group_by: "column")

    assert_instance_of Ryfinance::DownloadResult, result
    assert_equal ["MSFT", "AAPL"], result.tickers
    assert_equal 2, result.to_a.size
    assert result.to_a.first.key?(:"MSFT.close")
    assert result.to_a.first.key?(:"AAPL.close")
  end

  def test_download_uses_threads_without_changing_ticker_order
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { |uri| chart_fixture(uri.path.split("/").last) }
    client = Ryfinance::Client.new(transport: transport)

    result = Ryfinance.download("msft aapl", client: client, threads: 2)

    assert_equal ["MSFT", "AAPL"], result.tickers
    assert_equal 2, transport.requests.size
  end

  def test_download_reports_structured_progress
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { |uri| chart_fixture(uri.path.split("/").last) }
    client = Ryfinance::Client.new(transport: transport)
    events = []

    Ryfinance.download(
      "msft aapl",
      client: client,
      threads: false,
      progress: ->(**event) { events << event }
    )

    assert_equal ["MSFT", "AAPL"], events.map { |event| event[:ticker] }
    assert_equal [1, 2], events.map { |event| event[:completed] }
    assert_equal [2, 2], events.map { |event| event[:total] }
    assert events.all? { |event| event[:error].nil? }
  end

  def test_download_passes_repair_option_to_history
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { download_repair_fixture }
    client = Ryfinance::Client.new(transport: transport)

    result = Ryfinance.download("msft", client: client, auto_adjust: false, repair: true)

    assert_equal 111.0, result[1][:close]
    assert result[1][:repaired]
  end

  def test_download_accepts_proxy_keyword
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) { chart_fixture }
    client = Ryfinance::Client.new(transport: transport)

    Ryfinance.download("msft", client: client, proxy: "http://proxy.example:8080")

    assert_equal "http://proxy.example:8080", transport.requests.last[:proxy]
  end

  private

  def download_repair_fixture
    {
      "chart" => {
        "result" => [
          {
            "meta" => {
              "symbol" => "MSFT",
              "currency" => "USD",
              "exchangeTimezoneName" => "America/New_York"
            },
            "timestamp" => [1_704_067_200, 1_704_153_600, 1_704_240_000],
            "indicators" => {
              "quote" => [
                {
                  "open" => [99.0, 11_000.0, 111.0],
                  "high" => [101.0, 11_200.0, 113.0],
                  "low" => [98.0, 10_900.0, 110.0],
                  "close" => [100.0, 11_100.0, 112.0],
                  "volume" => [1000, 1200, 1400]
                }
              ],
              "adjclose" => [
                { "adjclose" => [100.0, 11_100.0, 112.0] }
              ]
            }
          }
        ],
        "error" => nil
      }
    }
  end
end
