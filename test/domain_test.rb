# frozen_string_literal: true

require_relative "test_helper"

class DomainTest < Minitest::Test
  def test_sector_fetches_and_parses_domain_data
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/sectors/technology}) { sector_fixture }
    client = Ryfinance::Client.new(transport: transport)

    sector = Ryfinance.sector("technology", client: client)

    assert_equal "technology", sector.key
    assert_equal "Technology", sector.name
    assert_equal "^YH101", sector.symbol
    assert_equal 800, sector.overview[:companies_count]
    assert_equal "Technology Select Sector SPDR Fund", sector.top_etfs["XLK"]
    assert_equal "Vanguard Information Technology Index", sector.top_mutual_funds["VITAX"]
    assert_equal 1, sector.industries.size
    assert_equal "software-infrastructure", sector.industries.first[:key]
    assert_equal "MSFT", sector.top_companies.first[:symbol]
    assert_instance_of Ryfinance::Ticker, sector.ticker
  end

  def test_industry_fetches_and_parses_domain_data
    transport = FakeTransport.new
    transport.route(%r{/v1/finance/industries/software-infrastructure}) { industry_fixture }
    client = Ryfinance::Client.new(transport: transport)

    industry = Ryfinance.industry("software-infrastructure", client: client)

    assert_equal "Software - Infrastructure", industry.name
    assert_equal "technology", industry.sector_key
    assert_equal "Technology", industry.sector_name
    assert_equal "DDOG", industry.top_growth_companies.first[:symbol]
    assert_equal "PLTR", industry.top_performing_companies.first[:symbol]
  end
end

