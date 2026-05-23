# RYFinance

RYFinance is a Ruby gem for Yahoo Finance data with an API shaped after Python's
`yfinance`. It focuses on the workflows most users reach for first:

- Single ticker access through `Ryfinance::Ticker`
- Multi-ticker history downloads through `Ryfinance.download`
- Quote info, fast quote data, recommendations, analyst targets, and calendar data
- Historical OHLCV rows with dividends, splits, and capital gains
- Options expiration dates and option chains
- Search and market summary helpers

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
gem build ryfinance.gemspec
```

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

## Historical Data

`Ticker#history` returns a `Ryfinance::Table`, an enumerable collection of row
hashes with CSV export helpers.

```ruby
rows = msft.history(
  period: "1y",
  interval: "1d",
  auto_adjust: true,
  actions: true
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
msft.calendar
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

Financial statement helpers:

```ruby
msft.income_stmt
msft.quarterly_income_stmt
msft.balance_sheet
msft.quarterly_balance_sheet
msft.cash_flow
msft.quarterly_cash_flow
msft.earnings
```

Yahoo returns these datasets with different coverage by ticker and asset type.
When Yahoo omits a module, RYFinance returns an empty table or hash instead of
inventing values.

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

market = Ryfinance.market(region: "US")
market.summary
```

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

## Compatibility Notes

RYFinance mirrors yfinance names where Ruby can express them cleanly, and it also
uses Ruby-style snake_case keys. Python's Pandas `DataFrame` is represented by
`Ryfinance::Table`.

See [docs/api.md](docs/api.md) and
[docs/yfinance_compatibility.md](docs/yfinance_compatibility.md) for details.

