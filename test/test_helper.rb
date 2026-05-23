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

def fund_quote_summary_fixture
  {
    "quoteSummary" => {
      "result" => [
        {
          "quoteType" => {
            "quoteType" => "ETF"
          },
          "summaryProfile" => {
            "longBusinessSummary" => "A total stock market ETF."
          },
          "topHoldings" => {
            "cashPosition" => { "raw" => 0.01 },
            "stockPosition" => { "raw" => 0.95 },
            "bondPosition" => { "raw" => 0.02 },
            "convertiblePosition" => { "raw" => 0.0 },
            "preferredPosition" => { "raw" => 0.0 },
            "otherPosition" => { "raw" => 0.02 },
            "holdings" => [
              {
                "symbol" => "AAPL",
                "holdingName" => "Apple Inc.",
                "holdingPercent" => { "raw" => 0.064 }
              }
            ],
            "equityHoldings" => {
              "priceToEarnings" => { "raw" => 21.1 },
              "priceToEarningsCat" => { "raw" => 22.2 },
              "priceToBook" => { "raw" => 4.2 },
              "priceToBookCat" => { "raw" => 4.4 },
              "priceToSales" => { "raw" => 2.8 },
              "priceToSalesCat" => { "raw" => 2.9 },
              "priceToCashflow" => { "raw" => 12.5 },
              "priceToCashflowCat" => { "raw" => 13.0 },
              "medianMarketCap" => { "raw" => 98_000_000_000 },
              "medianMarketCapCat" => { "raw" => 80_000_000_000 },
              "threeYearEarningsGrowth" => { "raw" => 0.08 },
              "threeYearEarningsGrowthCat" => { "raw" => 0.06 }
            },
            "bondHoldings" => {
              "maturity" => { "raw" => 8.1 },
              "maturityCat" => { "raw" => 7.0 },
              "duration" => { "raw" => 5.2 },
              "durationCat" => { "raw" => 4.8 },
              "creditQuality" => "AA",
              "creditQualityCat" => "A"
            },
            "bondRatings" => [
              { "usGovernment" => { "raw" => 0.2 } },
              { "aaa" => { "raw" => 0.3 } }
            ],
            "sectorWeightings" => [
              { "technology" => { "raw" => 0.28 } },
              { "healthcare" => { "raw" => 0.13 } }
            ]
          },
          "fundProfile" => {
            "categoryName" => "Large Blend",
            "family" => "Vanguard",
            "legalType" => "Exchange Traded Fund",
            "feesExpensesInvestment" => {
              "annualReportExpenseRatio" => { "raw" => 0.0003 },
              "annualHoldingsTurnover" => { "raw" => 0.04 },
              "totalNetAssets" => { "raw" => 1_000_000_000 }
            },
            "feesExpensesInvestmentCat" => {
              "annualReportExpenseRatio" => { "raw" => 0.005 },
              "annualHoldingsTurnover" => { "raw" => 0.3 },
              "totalNetAssets" => { "raw" => 500_000_000 }
            }
          }
        }
      ],
      "error" => nil
    }
  }
end

def stock_quote_summary_fixture
  {
    "quoteSummary" => {
      "result" => [
        {
          "quoteType" => {
            "quoteType" => "EQUITY"
          }
        }
      ],
      "error" => nil
    }
  }
end

def earnings_dates_fixture(rows: nil)
  {
    "finance" => {
      "result" => [
        {
          "documents" => [
            {
              "columns" => [
                { "label" => "Event Start Date" },
                { "label" => "Timezone short name" },
                { "label" => "EPS Estimate" },
                { "label" => "Reported EPS" },
                { "label" => "Surprise (%)" },
                { "label" => "Event Type" }
              ],
              "rows" => rows || [
                ["2026-04-23T20:00:00Z", "EDT", 3.2, 3.5, 9.4, "2"],
                ["2026-01-30T21:30:00Z", "EST", 2.9, 0.0, 0.0, "1"]
              ]
            }
          ]
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

def lookup_fixture(symbol: "AAPL", quote_type: "EQUITY")
  {
    "finance" => {
      "result" => [
        {
          "documents" => [
            {
              "symbol" => symbol,
              "shortName" => "Apple Inc.",
              "quoteType" => quote_type,
              "exchange" => "NMS",
              "regularMarketPrice" => { "raw" => 190.25, "fmt" => "190.25" },
              "marketCap" => { "raw" => 2_900_000_000_000 }
            }
          ]
        }
      ],
      "error" => nil
    }
  }
end

def lookup_error_fixture
  {
    "finance" => {
      "result" => [],
      "error" => {
        "code" => "Bad Request",
        "description" => "Invalid lookup query"
      }
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
