# API Reference

This document lists the public API provided by RYFinance 0.3.0.

## API Shape

RYFinance is Ruby-first. Unless a method appears in
[Compatibility Aliases](#compatibility-aliases), the API below is the canonical
Ruby API. Canonical entry points use:

- Direct class construction, such as `Ryfinance::Ticker.new("MSFT")`
- Lowercase module helpers, such as `Ryfinance.ticker("MSFT")`
- Keyword arguments and snake_case option names
- Blocks for streaming callbacks
- `Ryfinance::Table` and plain hashes instead of Pandas objects

yfinance-shaped names remain available as compatibility aliases for migration.

## Module Helpers

### `Ryfinance.ticker(ticker, session: nil, client: nil)`

Returns a `Ryfinance::Ticker`. Direct construction is equally canonical.

```ruby
Ryfinance.ticker("MSFT")
Ryfinance::Ticker.new("MSFT")
Ryfinance::Ticker.new(["OR", "XPAR"])
```

### `Ryfinance.tickers(tickers, session: nil, client: nil)`

Returns a `Ryfinance::Tickers` collection.

```ruby
Ryfinance.tickers("MSFT AAPL GOOG")
Ryfinance::Tickers.new("MSFT AAPL GOOG")
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
Ryfinance::Sector.new("financial-services")
```

### `Ryfinance.industry(key, session: nil, client: nil)`

Returns a `Ryfinance::Industry`.

```ruby
Ryfinance.industry("software-infrastructure")
Ryfinance::Industry.new("semiconductors")
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
ticker.income_statement
ticker.income_statement(as_dict: true)
ticker.quarterly_income_statement
ticker.ttm_income_statement
ticker.balance_sheet
ticker.quarterly_balance_sheet
ticker.cash_flow
ticker.quarterly_cash_flow
ticker.ttm_cash_flow
ticker.earnings
ticker.quarterly_earnings
```

Statement methods accept the same keyword options as their compatibility
getters:

```ruby
ticker.income_statement(freq: "yearly", as_dict: false)
ticker.balance_sheet(freq: "quarterly")
ticker.cash_flow(freq: "trailing")
ticker.earnings(freq: "quarterly")
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
ticker.shares_full(start: "2024-01-01", end: "2024-12-31")
ticker.isin
```

`isin` returns Yahoo-provided ISIN data when present. It does not scrape third
party websites.

### Live Streaming

```ruby
ticker.live(verbose: false) { |quote| puts quote }
socket = ticker.live(verbose: false)
```

When no handler is given, `live` returns a configured `Ryfinance::WebSocket`
with the ticker already subscribed.

## `Ryfinance::Tickers`

```ruby
tickers = Ryfinance::Tickers.new("MSFT AAPL")
tickers["MSFT"].info
tickers.history(period: "5d")
tickers.download(period: "1y")
tickers.live(verbose: false) { |quote| puts quote }
```

## `Ryfinance::WebSocket`

Blocking WebSocket client for Yahoo live pricing data.

```ruby
ws = Ryfinance::WebSocket.new(
  url: Ryfinance::AsyncWebSocket::DEFAULT_URL,
  verbose: true,
  heartbeat_interval: 15,
  reconnect: true,
  reconnect_delay: 3,
  raise_handler_errors: false
)

ws.subscribe(["AAPL", "BTC-USD"])
ws.unsubscribe("AAPL")
ws.listen { |quote| puts quote[:price] }
ws.close
```

`subscribe` and `unsubscribe` can be called before `listen` or while the stream
is active. Active streams receive the control message immediately.

Decoded quote hashes use snake_case symbol keys. Common keys include:

- `:id`
- `:price`
- `:time`
- `:currency`
- `:exchange`
- `:quote_type`
- `:market_hours`
- `:change_percent`
- `:day_volume`
- `:day_high`
- `:day_low`
- `:change`
- `:short_name`

## `Ryfinance::AsyncWebSocket`

Async-compatible WebSocket client for applications already using the `async`
gem. It has the same constructor and methods as `Ryfinance::WebSocket`, but
`listen` runs in the current async task instead of creating a top-level reactor.

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

## Compatibility Aliases

These public names are retained for yfinance migration or historical RYFinance
compatibility. New Ruby code should prefer the canonical names above.

### Module Constructors

| Compatibility alias | Canonical Ruby API |
| --- | --- |
| `Ryfinance.Ticker("MSFT")` | `Ryfinance::Ticker.new("MSFT")` or `Ryfinance.ticker("MSFT")` |
| `Ryfinance.Tickers("MSFT AAPL")` | `Ryfinance::Tickers.new("MSFT AAPL")` or `Ryfinance.tickers("MSFT AAPL")` |
| `Ryfinance.Sector("technology")` | `Ryfinance::Sector.new("technology")` or `Ryfinance.sector("technology")` |
| `Ryfinance.Industry("software")` | `Ryfinance::Industry.new("software")` or `Ryfinance.industry("software")` |
| `Ryfinance.WebSocket(...)` | `Ryfinance::WebSocket.new(...)` |
| `Ryfinance.AsyncWebSocket(...)` | `Ryfinance::AsyncWebSocket.new(...)` |

### Ticker Getter Methods

| Compatibility alias | Canonical Ruby API |
| --- | --- |
| `get_history_metadata` | `history_metadata` |
| `get_dividends` | `dividends` |
| `get_splits` | `splits` |
| `get_capital_gains` | `capital_gains` |
| `get_actions` | `actions` |
| `get_info` | `info` |
| `get_fast_info` | `fast_info` |
| `get_calendar` | `calendar` |
| `get_sec_filings` | `sec_filings` |
| `get_recommendations` | `recommendations` |
| `get_recommendations_summary` | `recommendations_summary` |
| `get_upgrades_downgrades` | `upgrades_downgrades` |
| `get_analyst_price_targets` | `analyst_price_targets` |
| `get_earnings_estimate` | `earnings_estimate` |
| `get_revenue_estimate` | `revenue_estimate` |
| `get_earnings_history` | `earnings_history` |
| `get_eps_trend` | `eps_trend` |
| `get_eps_revisions` | `eps_revisions` |
| `get_growth_estimates` | `growth_estimates` |
| `get_sustainability` | `sustainability` |
| `get_major_holders` | `major_holders` |
| `get_institutional_holders` | `institutional_holders` |
| `get_mutualfund_holders` | `mutualfund_holders` |
| `get_insider_transactions` | `insider_transactions` |
| `get_insider_roster_holders` | `insider_roster_holders` |
| `get_insider_purchases` | `insider_purchases` |
| `get_options` | `options` |
| `get_news` | `news` |
| `get_shares_full` | `shares_full` |
| `get_isin` | `isin` |

### Financial Statement Aliases

| Compatibility alias | Canonical Ruby API |
| --- | --- |
| `income_stmt`, `incomestmt`, `financials` | `income_statement` |
| `quarterly_income_stmt`, `quarterly_incomestmt`, `quarterly_financials` | `quarterly_income_statement` |
| `ttm_income_stmt`, `ttm_incomestmt`, `ttm_financials` | `ttm_income_statement` |
| `balancesheet` | `balance_sheet` |
| `quarterly_balancesheet` | `quarterly_balance_sheet` |
| `cashflow` | `cash_flow` |
| `quarterly_cashflow` | `quarterly_cash_flow` |
| `ttm_cashflow` | `ttm_cash_flow` |
| `get_income_stmt`, `get_incomestmt`, `get_financials` | `income_statement` |
| `get_balance_sheet`, `get_balancesheet` | `balance_sheet` |
| `get_cash_flow`, `get_cashflow` | `cash_flow` |
| `get_earnings` | `earnings` |

### Keyword Aliases

Some module methods accept both yfinance-style camelCase keyword arguments and
Ruby snake_case keywords. Prefer snake_case in new code, for example
`sort_field:` over `sortField:` and `user_id_type:` over `userIdType:`.

## Errors

All gem-specific errors inherit from `Ryfinance::Error`.

- `Ryfinance::InvalidTickerError`
- `Ryfinance::HTTPError`
- `Ryfinance::RateLimitError`
- `Ryfinance::YahooError`
- `Ryfinance::NotFoundError`
- `Ryfinance::UnsupportedFeatureError`
