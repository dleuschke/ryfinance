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
end
