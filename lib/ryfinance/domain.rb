# frozen_string_literal: true

module Ryfinance
  class Domain
    attr_reader :key

    def initialize(key, session: nil, client: nil)
      @key = key.to_s
      @client = client || session || Client.new
      @fetched = false
      @data = {}
      @name = nil
      @symbol = nil
      @overview = {}
      @top_companies = Table.new([])
      @research_reports = []
    end

    def name
      ensure_fetched
      @name
    end

    def symbol
      ensure_fetched
      @symbol
    end

    def ticker
      ensure_fetched
      @symbol.nil? ? nil : Ticker.new(@symbol, client: @client)
    end

    def overview
      ensure_fetched
      @overview
    end

    def top_companies
      ensure_fetched
      @top_companies
    end

    def research_reports
      ensure_fetched
      @research_reports
    end

    def to_h
      ensure_fetched
      Utils.deep_symbolize(Utils.unwrap_value(@data))
    end

    private

    def ensure_fetched
      fetch_and_parse unless @fetched
    end

    def fetch_and_parse
      @data = @client.domain(domain_type, @key)["data"] || {}
      parse_common(@data)
      parse_specific(@data)
      @fetched = true
    end

    def parse_common(data)
      @name = data["name"]
      @symbol = data["symbol"]
      @overview = Utils.deep_symbolize(Utils.unwrap_value(data.fetch("overview", {})))
      @top_companies = company_table(data.fetch("topCompanies", []))
      @research_reports = Array(data["researchReports"]).map { |row| Utils.deep_symbolize(Utils.unwrap_value(row)) }
    end

    def company_table(values)
      rows = Array(values).map do |company|
        {
          symbol: company["symbol"],
          name: company["name"],
          rating: Utils.unwrap_value(company["rating"]),
          market_weight: Utils.unwrap_value(company["marketWeight"])
        }
      end

      Table.new(rows, columns: %i[symbol name rating market_weight])
    end
  end

  class Sector < Domain
    def initialize(key, session: nil, client: nil)
      super(key, session: session, client: client)
      @top_etfs = {}
      @top_mutual_funds = {}
      @industries = Table.new([])
    end

    def top_etfs
      ensure_fetched
      @top_etfs
    end

    def top_mutual_funds
      ensure_fetched
      @top_mutual_funds
    end

    def industries
      ensure_fetched
      @industries
    end

    private

    def domain_type
      "sectors"
    end

    def parse_specific(data)
      @top_etfs = symbol_name_map(data.fetch("topETFs", []))
      @top_mutual_funds = symbol_name_map(data.fetch("topMutualFunds", []))
      @industries = industry_table(data.fetch("industries", []))
    end

    def symbol_name_map(values)
      Array(values).each_with_object({}) do |item, result|
        symbol = item["symbol"]
        result[symbol] = item["name"] unless symbol.nil?
      end
    end

    def industry_table(values)
      rows = Array(values).filter_map do |industry|
        next if industry["name"] == "All Industries"

        {
          key: industry["key"],
          name: industry["name"],
          symbol: industry["symbol"],
          market_weight: Utils.unwrap_value(industry["marketWeight"])
        }
      end

      Table.new(rows, columns: %i[key name symbol market_weight])
    end
  end

  class Industry < Domain
    def initialize(key, session: nil, client: nil)
      super(key, session: session, client: client)
      @sector_key = nil
      @sector_name = nil
      @top_growth_companies = Table.new([])
      @top_performing_companies = Table.new([])
    end

    def sector_key
      ensure_fetched
      @sector_key
    end

    def sector_name
      ensure_fetched
      @sector_name
    end

    def top_growth_companies
      ensure_fetched
      @top_growth_companies
    end

    def top_performing_companies
      ensure_fetched
      @top_performing_companies
    end

    private

    def domain_type
      "industries"
    end

    def parse_specific(data)
      @sector_key = data["sectorKey"]
      @sector_name = data["sectorName"]
      @top_growth_companies = company_table(data.fetch("topGrowthCompanies", []))
      @top_performing_companies = company_table(data.fetch("topPerformingCompanies", []))
    end
  end
end
