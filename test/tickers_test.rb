# frozen_string_literal: true

require_relative "test_helper"

class TickersTest < Minitest::Test
  def test_history_captures_per_ticker_errors
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) do |uri|
      symbol = uri.path.split("/").last
      symbol == "FAIL" ? chart_error_fixture(symbol) : chart_fixture(symbol)
    end
    tickers = Ryfinance::Tickers.new("msft fail", client: Ryfinance::Client.new(transport: transport))

    result = tickers.history(period: "1mo")

    assert_instance_of Ryfinance::DownloadResult, result
    assert_equal ["MSFT", "FAIL"], result.tickers
    assert_equal ["MSFT"], result.successful_tickers
    assert_equal ["FAIL"], result.failed_tickers
    assert_instance_of Ryfinance::NotFoundError, result.errors["FAIL"]
    assert_equal 2, result["MSFT"].size
    assert_empty result["FAIL"]
  end

  def test_history_can_raise_per_ticker_errors
    transport = FakeTransport.new
    transport.route(%r{/v8/finance/chart/}) do |uri|
      symbol = uri.path.split("/").last
      symbol == "FAIL" ? chart_error_fixture(symbol) : chart_fixture(symbol)
    end
    tickers = Ryfinance::Tickers.new("msft fail", client: Ryfinance::Client.new(transport: transport))

    assert_raises(Ryfinance::NotFoundError) do
      tickers.history(period: "1mo", raise_errors: true)
    end
  end

  private

  def chart_error_fixture(symbol)
    {
      "chart" => {
        "result" => nil,
        "error" => {
          "code" => "Not Found",
          "description" => "No data found for #{symbol}"
        }
      }
    }
  end
end
