# API Reference

This document lists the public API provided by RYFinance 0.2.0.

## Module Functions

### `Ryfinance.Ticker(ticker, session: nil, client: nil)`

Returns a `Ryfinance::Ticker`.

```ruby
Ryfinance.Ticker("MSFT")
Ryfinance.Ticker(["OR", "XPAR"])
```

### `Ryfinance.Tickers(tickers, session: nil, client: nil)`

Returns a `Ryfinance::Tickers` collection.

```ruby
Ryfinance.Tickers("MSFT AAPL GOOG")
```

### `Ryfinance.download(tickers, **options)`

Downloads historical data for one or more tickers.

Common options:

- `period:` one of `1d 5d 1mo 3mo 6mo 1y 2y 5y 10y ytd max`
- `interval:` one of `1m 2m 5m 15m 30m 60m 90m 1h 1d 5d 1wk 1mo 3mo`
- `start:` explicit inclusive start date or time
- `end:` explicit exclusive end date or time
- `group_by:` `"column"` or `"ticker"`
- `auto_adjust:` adjust OHLC using adjusted close
- `actions:` include dividends, splits, and capital gains
- `prepost:` include pre-market and post-market bars
- `rounding:` round numeric float values to two decimals
- `timeout:` HTTP timeout in seconds
- `multi_level_index:` when true, always return `DownloadResult`

For one ticker the default return is `Ryfinance::Table`. For multiple tickers the
return is `Ryfinance::DownloadResult`.

### `Ryfinance.search(query, **options)`

Runs Yahoo Finance search and returns a `Ryfinance::Search`.

Options:

- `quotes_count:`
- `news_count:`
- `lists_count:`
- `timeout:`

### `Ryfinance.market(region: "US")`

Returns a `Ryfinance::Market` object. Call `#summary` to fetch market summary
rows.

### `Ryfinance.sector(key, session: nil, client: nil)`

Returns a `Ryfinance::Sector`.

```ruby
Ryfinance.sector("technology")
Ryfinance.Sector("financial-services")
```

### `Ryfinance.industry(key, session: nil, client: nil)`

Returns a `Ryfinance::Industry`.

```ruby
Ryfinance.industry("software-infrastructure")
Ryfinance.Industry("semiconductors")
```

### `Ryfinance.screen(query, **options)`

Runs a predefined or custom Yahoo screener.

```ruby
Ryfinance.screen("day_gainers", count: 25)

query = Ryfinance::EquityQuery.new("and", [
  Ryfinance::EquityQuery.new("gt", ["percentchange", 3]),
  Ryfinance::EquityQuery.new("eq", ["region", "us"])
])
Ryfinance.screen(query, sort_field: "percentchange", sort_asc: true)
```

Options:

- `offset:`
- `size:`
- `count:`
- `sortField:` or `sort_field:`
- `sortAsc:` or `sort_asc:`
- `userId:` or `user_id:`
- `userIdType:` or `user_id_type:`
- `timeout:`

Predefined screen names are available through
`Ryfinance::PREDEFINED_SCREENER_QUERIES.keys`.

### `Ryfinance.set_tz_cache_location(path)`

Configures a JSON timezone metadata cache. Set `nil` to disable it.

```ruby
Ryfinance.set_tz_cache_location(".ryfinance-cache")
Ryfinance.timezone_cache.get("MSFT")
```

## `Ryfinance::Ticker`

### Construction

```ruby
ticker = Ryfinance::Ticker.new("MSFT")
```

Supported ticker forms:

- A Yahoo symbol string such as `"MSFT"` or `"^GSPC"`
- A two-element array `[symbol, mic_code]` for common market identifier codes

### Price History

```ruby
ticker.history(period: "1mo", interval: "1d")
ticker.history(start: "2024-01-01", end: "2024-02-01")
ticker.history(actions: true, auto_adjust: false)
```

Returns a `Ryfinance::Table` with columns:

- `date`
- `open`
- `high`
- `low`
- `close`
- `volume`
- `adj_close`
- `dividends`, when `actions: true`
- `stock_splits`, when `actions: true`
- `capital_gains`, when `actions: true`

### Corporate Actions

```ruby
ticker.dividends
ticker.splits
ticker.capital_gains
ticker.actions
```

### Quote and Company Info

```ruby
ticker.info
ticker.fast_info
ticker.calendar
ticker.sec_filings
ticker.news(count: 10)
```

`info` returns a flattened hash combining Yahoo quote summary modules and quote
data. Keys are snake_case symbols.

### Analysis and Holders

```ruby
ticker.recommendations
ticker.recommendations_summary
ticker.upgrades_downgrades
ticker.analyst_price_targets
ticker.earnings_estimate
ticker.revenue_estimate
ticker.earnings_history
ticker.eps_trend
ticker.eps_revisions
ticker.growth_estimates
ticker.sustainability
ticker.major_holders
ticker.institutional_holders
ticker.mutualfund_holders
ticker.insider_transactions
ticker.insider_roster_holders
ticker.insider_purchases
```

Table-returning methods accept `as_dict: true`, which returns an array of row
hashes.

### Financial Statements

```ruby
ticker.income_stmt
ticker.quarterly_income_stmt
ticker.ttm_income_stmt
ticker.balance_sheet
ticker.quarterly_balance_sheet
ticker.cash_flow
ticker.quarterly_cash_flow
ticker.ttm_cash_flow
ticker.earnings
ticker.quarterly_earnings
```

Getter methods are also available:

```ruby
ticker.get_income_stmt(freq: "yearly", as_dict: false)
ticker.get_balance_sheet(freq: "quarterly")
ticker.get_cash_flow(freq: "yearly")
ticker.get_earnings(freq: "quarterly")
```

### Options

```ruby
ticker.options
ticker.option_chain
ticker.option_chain("2026-01-16")
```

`option_chain` returns `Ryfinance::OptionChain` with:

- `calls`
- `puts`
- `underlying`

### Shares and ISIN

```ruby
ticker.get_shares_full(start: "2024-01-01", end: "2024-12-31")
ticker.isin
```

`isin` returns Yahoo-provided ISIN data when present. It does not scrape third
party websites.

## `Ryfinance::Tickers`

```ruby
tickers = Ryfinance::Tickers.new("MSFT AAPL")
tickers["MSFT"].info
tickers.history(period: "5d")
tickers.download(period: "1y")
```

## `Ryfinance::EquityQuery`, `FundQuery`, and `ETFQuery`

Query builders serialize to Yahoo screener query hashes.

```ruby
Ryfinance::EquityQuery.new("gt", ["percentchange", 3])
Ryfinance::FundQuery.new("eq", ["categoryname", "Large Blend"])
Ryfinance::ETFQuery.new("eq", ["region", "us"])
```

Supported operators:

- `eq`
- `is-in`
- `btwn`
- `gt`
- `lt`
- `gte`
- `lte`
- `and`
- `or`

`valid_fields` and `valid_values` expose the common Yahoo fields documented for
each asset class.

## `Ryfinance::Sector`

```ruby
sector = Ryfinance::Sector.new("technology")
sector.key
sector.name
sector.symbol
sector.ticker
sector.overview
sector.top_companies
sector.research_reports
sector.top_etfs
sector.top_mutual_funds
sector.industries
```

## `Ryfinance::Industry`

```ruby
industry = Ryfinance::Industry.new("software-infrastructure")
industry.key
industry.name
industry.symbol
industry.ticker
industry.overview
industry.top_companies
industry.research_reports
industry.sector_key
industry.sector_name
industry.top_growth_companies
industry.top_performing_companies
```

## `Ryfinance::Table`

`Table` is an enumerable wrapper around row hashes.

```ruby
table.each { |row| puts row[:close] }
table[:close]
table.first
table.last(10)
table.where { |row| row[:close].to_f > 100 }
table.to_a
table.to_h(index: :date)
table.to_csv
```

## Errors

All gem-specific errors inherit from `Ryfinance::Error`.

- `Ryfinance::InvalidTickerError`
- `Ryfinance::HTTPError`
- `Ryfinance::RateLimitError`
- `Ryfinance::YahooError`
- `Ryfinance::NotFoundError`
- `Ryfinance::UnsupportedFeatureError`
