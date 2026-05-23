# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "tmpdir"
require "ryfinance"

class FakeTransport
  attr_reader :requests

  def initialize
    @routes = []
    @requests = []
  end

  def route(pattern, body = nil, &block)
    @routes << [pattern, block || proc { body }]
  end

  def get(uri, headers:, timeout:)
    @requests << { method: :get, uri: uri, headers: headers, timeout: timeout }
    response_for(body_for(uri))
  end

  def post(uri, headers:, body:, timeout:)
    @requests << { method: :post, uri: uri, headers: headers, body: body, timeout: timeout }
    response_for(body_for(uri))
  end

  private

  def body_for(uri)
    route = @routes.find { |pattern, _handler| pattern === uri.to_s || pattern === uri.path }
    raise "No fake route for #{uri}" unless route

    route.last.call(uri)
  end

  def response_for(value)
    if value.is_a?(Ryfinance::Response)
      value
    elsif value.is_a?(Hash) && value.key?(:code) && value.key?(:body)
      {
        code: value.fetch(:code),
        body: value.fetch(:body),
        headers: value.fetch(:headers, {})
      }
    else
      { code: 200, body: JSON.generate(value), headers: { "content-type" => "application/json" } }
    end
  end
end

def chart_fixture(symbol = "MSFT")
  {
    "chart" => {
      "result" => [
        {
          "meta" => {
            "symbol" => symbol,
            "currency" => "USD",
            "exchangeTimezoneName" => "America/New_York"
          },
          "timestamp" => [1_704_067_200, 1_704_153_600],
          "indicators" => {
            "quote" => [
              {
                "open" => [99.0, 110.0],
                "high" => [101.0, 112.0],
                "low" => [98.0, 109.0],
                "close" => [100.0, 111.0],
                "volume" => [1000, 1500]
              }
            ],
            "adjclose" => [
              { "adjclose" => [50.0, 111.0] }
            ]
          },
          "events" => {
            "dividends" => {
              "1704067200" => { "date" => 1_704_067_200, "amount" => 0.5 }
            },
            "splits" => {
              "1704153600" => {
                "date" => 1_704_153_600,
                "numerator" => 2,
                "denominator" => 1,
                "splitRatio" => "2:1"
              }
            }
          }
        }
      ],
      "error" => nil
    }
  }
end

def quote_fixture(symbol = "MSFT")
  {
    "quoteResponse" => {
      "result" => [
        {
          "symbol" => symbol,
          "regularMarketPrice" => 420.25,
          "regularMarketPreviousClose" => 418.0,
          "regularMarketOpen" => 419.0,
          "regularMarketDayHigh" => 423.0,
          "regularMarketDayLow" => 417.5,
          "regularMarketVolume" => 12_345_678,
          "fiftyDayAverage" => 410.5,
          "twoHundredDayAverage" => 390.1,
          "marketCap" => 3_000_000_000,
          "currency" => "USD"
        }
      ],
      "error" => nil
    }
  }
end

def quote_summary_fixture
  {
    "quoteSummary" => {
      "result" => [
        {
          "price" => {
            "longName" => "Microsoft Corporation",
            "regularMarketPrice" => { "raw" => 420.25, "fmt" => "420.25" }
          },
          "financialData" => {
            "targetMeanPrice" => { "raw" => 450.0, "fmt" => "450.00" },
            "targetLowPrice" => { "raw" => 390.0, "fmt" => "390.00" },
            "targetHighPrice" => { "raw" => 510.0, "fmt" => "510.00" },
            "targetMedianPrice" => { "raw" => 455.0, "fmt" => "455.00" },
            "currentPrice" => { "raw" => 420.25, "fmt" => "420.25" }
          },
          "calendarEvents" => {
            "earnings" => {
              "earningsDate" => [{ "raw" => 1_711_324_800, "fmt" => "2024-03-25" }]
            }
          },
          "recommendationTrend" => {
            "trend" => [
              { "period" => "0m", "strongBuy" => 10, "buy" => 20, "hold" => 5 }
            ]
          }
        }
      ],
      "error" => nil
    }
  }
end

def options_fixture
  {
    "optionChain" => {
      "result" => [
        {
          "expirationDates" => [1_704_153_600],
          "quote" => { "symbol" => "MSFT", "regularMarketPrice" => 420.25 },
          "options" => [
            {
              "calls" => [
                {
                  "contractSymbol" => "MSFT240102C00420000",
                  "lastTradeDate" => 1_704_067_200,
                  "strike" => 420.0,
                  "lastPrice" => 3.5,
                  "bid" => 3.4,
                  "ask" => 3.6,
                  "volume" => 10,
                  "openInterest" => 100,
                  "impliedVolatility" => 0.2,
                  "inTheMoney" => true,
                  "contractSize" => "REGULAR",
                  "currency" => "USD"
                }
              ],
              "puts" => []
            }
          ]
        }
      ],
      "error" => nil
    }
  }
end

def screener_fixture
  {
    "finance" => {
      "result" => [
        {
          "count" => 1,
          "quotes" => [
            {
              "symbol" => "MSFT",
              "shortName" => "Microsoft Corporation",
              "regularMarketPrice" => { "raw" => 420.25, "fmt" => "420.25" }
            }
          ]
        }
      ],
      "error" => nil
    }
  }
end

def sector_fixture
  {
    "data" => {
      "name" => "Technology",
      "symbol" => "^YH101",
      "overview" => {
        "companiesCount" => 800,
        "marketCap" => { "raw" => 12_000_000_000_000 },
        "marketWeight" => { "raw" => 0.31 }
      },
      "topCompanies" => [
        { "symbol" => "MSFT", "name" => "Microsoft", "rating" => "Buy", "marketWeight" => { "raw" => 0.08 } }
      ],
      "topETFs" => [
        { "symbol" => "XLK", "name" => "Technology Select Sector SPDR Fund" }
      ],
      "topMutualFunds" => [
        { "symbol" => "VITAX", "name" => "Vanguard Information Technology Index" }
      ],
      "industries" => [
        { "key" => "all-industries", "name" => "All Industries", "symbol" => "^YH0", "marketWeight" => { "raw" => 1.0 } },
        { "key" => "software-infrastructure", "name" => "Software - Infrastructure", "symbol" => "^YH101-010", "marketWeight" => { "raw" => 0.12 } }
      ],
      "researchReports" => [
        { "title" => "Technology outlook", "provider" => "Example" }
      ]
    }
  }
end

def industry_fixture
  {
    "data" => {
      "name" => "Software - Infrastructure",
      "symbol" => "^YH101-010",
      "sectorKey" => "technology",
      "sectorName" => "Technology",
      "overview" => {
        "companiesCount" => 120,
        "marketCap" => { "raw" => 3_000_000_000_000 }
      },
      "topCompanies" => [
        { "symbol" => "MSFT", "name" => "Microsoft", "rating" => "Buy", "marketWeight" => { "raw" => 0.22 } }
      ],
      "topGrowthCompanies" => [
        { "symbol" => "DDOG", "name" => "Datadog", "rating" => "Hold", "marketWeight" => { "raw" => 0.02 } }
      ],
      "topPerformingCompanies" => [
        { "symbol" => "PLTR", "name" => "Palantir", "rating" => "Buy", "marketWeight" => { "raw" => 0.04 } }
      ],
      "researchReports" => []
    }
  }
end
