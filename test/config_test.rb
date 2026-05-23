# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_set_tz_cache_location_persists_history_timezone
    Dir.mktmpdir do |dir|
      previous = Ryfinance.tz_cache_location
      Ryfinance.set_tz_cache_location(dir)

      transport = FakeTransport.new
      transport.route(%r{/v8/finance/chart/}) { chart_fixture }
      client = Ryfinance::Client.new(transport: transport)

      Ryfinance::Ticker.new("msft", client: client).history

      assert_equal "America/New_York", Ryfinance.timezone_cache.get("MSFT")
      assert File.file?(File.join(dir, "tz_cache.json"))
    ensure
      Ryfinance.set_tz_cache_location(previous)
    end
  end
end
