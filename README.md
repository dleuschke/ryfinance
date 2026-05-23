# RYFinance

[![CI](https://github.com/dleuschke/ryfinance/actions/workflows/ci.yml/badge.svg)](https://github.com/dleuschke/ryfinance/actions/workflows/ci.yml)

RYFinance is a Ruby-first gem for Yahoo Finance data. It ports the practical
surface area of Python's `yfinance`, but the primary API is designed around Ruby
classes, keyword arguments, blocks, and `Enumerable`-friendly data structures.
It focuses on the workflows most users reach for first:

- Single ticker access through `Ryfinance::Ticker`
- Multi-ticker history downloads through `Ryfinance.download`
- Quote info, fast quote data, recommendations, analyst targets, and calendar data
- Historical OHLCV rows with dividends, splits, and capital gains
- Options expiration dates and option chains
- ETF and mutual fund holdings, allocations, and fund operations
- WebSocket streaming plus search, screener, calendar, market, sector, and industry helpers

RYFinance is not affiliated with Yahoo, Yahoo Finance, or the Python `yfinance`
project. Yahoo Finance is intended for personal, research, and educational use;
review Yahoo's terms before using the data in a product.

## Installation

Add the gem to your application:

```ruby
gem "ryfinance"
```

Then install:

```sh
bundle install
```

For local development from this repository:

```sh
bundle exec rake test
bundle exec rake ci
```

Release steps are documented in [docs/releasing.md](docs/releasing.md).

## Quick Start

```ruby
require "ryfinance"

msft = Ryfinance::Ticker.new("MSFT")

history = msft.history(period: "1mo")
puts history.first
#=> {:date=>2026-..., :open=>..., :high=>..., :low=>..., :close=>..., ...}

info = msft.info
puts info[:long_name]

fast = msft.fast_info
puts fast[:last_price]
```

You can also use top-level constructors that mirror Python `yfinance` naming:

```ruby
msft = Ryfinance.Ticker("MSFT")
tickers = Ryfinance.Tickers("MSFT AAPL GOOG")
```

Those constructors are compatibility shims. New Ruby code should prefer
`Ryfinance::Ticker.new`, `Ryfinance::Tickers.new`, or the lowercase helpers
`Ryfinance.ticker` and `Ryfinance.tickers`.

## Historical Data

`Ticker#history` returns a `Ryfinance::Table`, an enumerable collection of row
hashes with CSV export helpers.

```ruby
rows = msft.history(
  period: "1y",
  interval: "1d",
  auto_adjust: true,
  actions: true,
  repair: true
)

rows.each do |row|
  puts "#{row[:date]} #{row[:close]} #{row[:volume]}"
end

File.write("msft.csv", rows.to_csv)
```

Valid periods:

```text
1d 5d 1mo 3mo 6mo 1y 2y 5y 10y ytd max
```

Valid intervals:

```text
1m 2m 5m 15m 30m 60m 90m 1h 1d 5d 1wk 1mo 3mo
```

Use `start:` and `end:` for explicit ranges. Like yfinance, `end:` is exclusive.

```ruby
msft.history(start: "2024-01-01", end: "2024-02-01")
```

Pass `repair: true` to run yfinance-style price repair passes before adjustment.
Current repairs cover 100x currency/unit mixups, zero or missing traded prices,
bad split adjustment jumps, missing dividend adjustment, OHLC bound violations,
and dividend/capital-gain unit mixups. Repaired tables include `:repaired` and
`:repair_actions` columns, plus a `metadata[:repairs]` summary.

## Corporate Actions

```ruby
msft.dividends
msft.splits
msft.capital_gains
msft.actions
```

Each method returns a `Ryfinance::Table` filtered to rows with that action.

## Multi-Ticker Downloads

```ruby
data = Ryfinance.download("MSFT AAPL", period: "6mo", group_by: "column")

data.tickers
#=> ["MSFT", "AAPL"]

data["MSFT"].last
data.to_a.first
#=> {:date=>..., :"MSFT.close"=>..., :"AAPL.close"=>...}
```

For one ticker, `Ryfinance.download("MSFT")` returns a `Ryfinance::Table` by
default. Pass `multi_level_index: true` if you always want a `DownloadResult`.

## Quote, Analysis, and Financial Data

```ruby
msft.info
msft.fast_info
msft.valuation
msft.calendar
msft.earnings_dates
msft.sec_filings
msft.recommendations
msft.upgrades_downgrades
msft.analyst_price_targets
msft.earnings_estimate
msft.revenue_estimate
msft.eps_trend
msft.eps_revisions
msft.growth_estimates
msft.sustainability
```

`earnings_dates(limit: 12, offset: 0)` returns a `Ryfinance::Table` with
`:earnings_date`, EPS, surprise, event type, and timezone columns. It returns
`nil` when Yahoo has no earnings calendar rows for the ticker.

`valuation` returns a `Ryfinance::Table` of current valuation metrics such as
market cap, enterprise value, PE ratios, PEG ratio, price/book, and
enterprise-value multiples.

Financial statement helpers:

```ruby
msft.income_statement
msft.quarterly_income_statement
msft.balance_sheet
msft.quarterly_balance_sheet
msft.cash_flow
msft.quarterly_cash_flow
msft.earnings
```

Shares outstanding:

```ruby
msft.shares
msft.shares_full(start: "2024-01-01", end: "2024-12-31")
```

Yahoo returns these datasets with different coverage by ticker and asset type.
When Yahoo omits a module, RYFinance returns an empty table or hash instead of
inventing values.

## ETF and Mutual Fund Data

`Ticker#funds_data` mirrors yfinance's fund-specific object for ETFs and mutual
funds. It returns `nil` for ordinary equities.

```ruby
fund = Ryfinance::Ticker.new("VTI").funds_data

fund.quote_type
fund.description
fund.fund_overview
fund.top_holdings
fund.asset_classes
fund.sector_weightings
fund.bond_ratings
fund.equity_holdings
fund.bond_holdings
fund.fund_operations
```

Holdings and peer-comparison datasets are returned as `Ryfinance::Table`
objects. Allocation datasets are returned as snake_case Ruby hashes.

## Options

```ruby
expirations = msft.options
chain = msft.option_chain(expirations.first)

chain.calls.first
chain.puts.first
chain.underlying
```

## Search and Markets

```ruby
result = Ryfinance.search("Microsoft", quotes_count: 5, news_count: 3)

result.quotes
result.news

lookup = Ryfinance.lookup("apple")
lookup.stock
lookup.etf
lookup.get_cryptocurrency(count: 10)

market = Ryfinance.market("US")
market.status
market.summary

calendars = Ryfinance.calendars(start: "2026-04-01", end: "2026-04-30")
calendars.earnings_calendar
calendars.ipo_info_calendar
calendars.economic_events_calendar
calendars.splits_calendar
```

`Ryfinance::Lookup` returns typed instrument results as `Ryfinance::Table`
objects. Available categories are `all`, `stock`, `mutualfund`, `etf`, `index`,
`future`, `currency`, and `cryptocurrency`.

`Ryfinance::Market#status` returns a snake_case hash with current market state,
open/close `Time` values, and timezone details. `#summary` returns a
`Ryfinance::Table` of market index rows. Yahoo supports `US`, `GB`, `ASIA`,
`EUROPE`, `RATES`, `COMMODITIES`, `CURRENCIES`, and `CRYPTOCURRENCIES`.

`Ryfinance::Calendars` returns market-wide Yahoo calendar tables for earnings,
IPOs, economic events, and stock splits. Date-like values are normalized to UTC
`Time` objects and columns use snake_case symbol keys.

## Live Streaming

Yahoo's live stream uses WebSocket frames containing base64-encoded protobuf
quotes. RYFinance decodes those frames into snake_case Ruby hashes.

```ruby
ws = Ryfinance::WebSocket.new(verbose: false)
ws.subscribe(["AAPL", "BTC-USD"])

begin
  ws.listen do |quote|
    puts "#{quote[:id]} #{quote[:price]} #{quote[:change_percent]}"
  end
ensure
  ws.close
end
```

Ticker helpers subscribe for you:

```ruby
Ryfinance::Ticker.new("MSFT").live(verbose: false) do |quote|
  puts quote
end
```

For applications already using the `async` gem:

```ruby
require "async"

Async do
  ws = Ryfinance::AsyncWebSocket.new(verbose: false)
  ws.subscribe("MSFT")
  ws.listen { |quote| puts quote[:price] }
ensure
  ws&.close
end
```

`subscribe` and `unsubscribe` seed the next connection and, when a stream is
already open, send the control message immediately. The client periodically
resends the active subscription list as a heartbeat.

Live streaming has an opt-in smoke test that connects to Yahoo and waits for one
quote. It defaults to `BTC-USD` so it can run outside US market hours:

```sh
RYFINANCE_LIVE=1 bundle exec rake test:live
```

Use `RYFINANCE_LIVE_SYMBOL=MSFT` or `RYFINANCE_LIVE_TIMEOUT=30` to override the
default symbol and timeout. This test is intentionally excluded from normal CI.

## Screeners

Run Yahoo's predefined screens:

```ruby
gainers = Ryfinance.screen("day_gainers", count: 25)
gainers[:quotes].map { |quote| quote[:symbol] }
```

Build custom screens with query objects:

```ruby
query = Ryfinance::EquityQuery.new("and", [
  Ryfinance::EquityQuery.new("gt", ["percentchange", 3]),
  Ryfinance::EquityQuery.new("eq", ["region", "us"])
])

Ryfinance.screen(query, sort_field: "percentchange", sort_asc: true)
```

`Ryfinance::FundQuery` and `Ryfinance::ETFQuery` are also available. The
predefined query map is exposed as `Ryfinance::PREDEFINED_SCREENER_QUERIES`.

## Sectors and Industries

```ruby
technology = Ryfinance.sector("technology")

technology.name
technology.overview
technology.top_companies
technology.top_etfs
technology.top_mutual_funds
technology.industries

software = Ryfinance.industry("software-infrastructure")
software.sector_name
software.top_growth_companies
software.top_performing_companies
```

Sector and industry tables use `Ryfinance::Table`, like historical price data.

## Table API

`Ryfinance::Table` is intentionally simple and Ruby-native:

```ruby
table.size
table.empty?
table.columns
table[:close]
table.first
table.last(5)
table.where { |row| row[:volume].to_i > 1_000_000 }
table.to_a
table.to_h(index: :date)
table.to_csv
```

## Transport Injection

Tests and applications can inject a custom HTTP transport:

```ruby
client = Ryfinance::Client.new(transport: my_transport)
msft = Ryfinance::Ticker.new("MSFT", client: client)
```

The transport must implement:

```ruby
get(uri, headers:, timeout:)
post(uri, headers:, body:, timeout:)
```

and return either `Ryfinance::Response` or a hash with `:code`, `:body`, and
optional `:headers`.

Streaming tests and advanced integrations can inject a live transport:

```ruby
ws = Ryfinance::WebSocket.new(transport: my_live_transport)
```

The live transport must implement:

```ruby
stream(url:, subscriptions:, heartbeat_interval:, stop_if:, on_message:, on_connection: nil)
```

## Yahoo Cookies and Crumbs

`Ryfinance::Client` uses a lazy Yahoo cookie/crumb fallback. Normal requests are
sent without a crumb first. If Yahoo responds with an authorization-style HTTP
error, the client fetches a Yahoo cookie, retrieves a crumb from Yahoo's test
endpoint, and retries the request with `crumb=...`.

```ruby
client = Ryfinance::Client.new
msft = Ryfinance::Ticker.new("MSFT", client: client)
```

The fallback can be disabled for tests or custom infrastructure:

```ruby
client = Ryfinance::Client.new(crumb: false)
```

Use `crumb: :always` to fetch and attach a crumb before the first request.

## Response Cache and Retries

GET response caching is opt-in. Use `Ryfinance::MemoryCache` for scripts, or
provide an object that responds to `read(key)`, `write(key, value, expires_in:)`,
and optionally `clear`.

```ruby
cache = Ryfinance::MemoryCache.new(max_size: 500)
client = Ryfinance::Client.new(cache: cache, cache_ttl: 60)

Ryfinance::Ticker.new("MSFT", client: client).info
client.clear_cache
```

Only successful GET responses are cached; POST requests, failed responses, and
WebSocket messages are not cached. The client also retries transient Yahoo HTTP
responses by default:

```ruby
client = Ryfinance::Client.new(
  retries: 2,
  retry_backoff: 0.5,
  retry_max_sleep: 5
)
```

Retries apply to HTTP 429, 500, 502, 503, and 504 responses and honor
`Retry-After` when Yahoo sends it.

## Timezone Cache

`set_tz_cache_location` stores exchange timezone metadata learned from history
responses in a small JSON cache:

```ruby
Ryfinance.set_tz_cache_location(".ryfinance-cache")
Ryfinance::Ticker.new("MSFT").history(period: "1d")
Ryfinance.timezone_cache.get("MSFT")
```

## Compatibility Notes

RYFinance keeps yfinance-style names where they help migration, but those names
are treated as a compatibility layer. The canonical API uses direct class
construction, lowercase module helpers, Ruby keyword arguments, block-based
streaming, snake_case symbol keys, and `Ryfinance::Table` instead of Pandas
`DataFrame`.

See [docs/api.md](docs/api.md) and
[docs/yfinance_compatibility.md](docs/yfinance_compatibility.md) for details.
