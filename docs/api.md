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
- `repair:` run price, action, split, and adjustment repair passes before
  auto/back adjustment
- `timeout:` HTTP timeout in seconds
- `proxy:` proxy URI string, `URI`, or hash
- `threads:` `true`, `false`, or an integer worker count for multi-ticker
  downloads
- `progress:` `true` to print per-ticker updates, or any callable object to
  receive structured progress events
- `multi_level_index:` when true, always return `DownloadResult`

For one ticker the default return is `Ryfinance::Table`. For multiple tickers the
return is `Ryfinance::DownloadResult`.

Progress callables receive keyword arguments:

```ruby
events = []
Ryfinance.download(
  "MSFT AAPL",
  threads: 2,
  progress: ->(**event) { events << event }
)

events.first
#=> {:ticker=>"MSFT", :completed=>1, :total=>2, :error=>nil}
```

### `Ryfinance.search(query, **options)`

Runs Yahoo Finance search and returns a `Ryfinance::Search`.

Options:

- `quotes_count:`
- `news_count:`
- `lists_count:`
- `timeout:`

### `Ryfinance.lookup(query, **options)`

Returns a `Ryfinance::Lookup` object for typed instrument discovery.

```ruby
lookup = Ryfinance.lookup("apple")
lookup.stock
lookup.etf
lookup.get_cryptocurrency(count: 10)
```

Options:

- `timeout:`
- `raise_errors:`

### `Ryfinance.market(market = nil, region: "US", session: nil, client: nil)`

Returns a `Ryfinance::Market` object. Call `#summary` to fetch market summary
rows and `#status` to fetch current market status.

```ruby
market = Ryfinance.market("EUROPE")
market.status
market.summary
```

Use `Ryfinance.Market("US")` as a yfinance-shaped constructor shim.

### `Ryfinance.calendars(start: nil, end_date: nil, session: nil, client: nil)`

Returns a `Ryfinance::Calendars` object for market-wide event calendars.

```ruby
calendars = Ryfinance.calendars(start: "2026-04-01", end: "2026-04-30")
calendars.earnings_calendar
calendars.ipo_info_calendar
calendars.economic_events_calendar
calendars.splits_calendar
```

Pass `end:` as a compatibility keyword when porting yfinance-shaped code.

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
ticker.history(repair: true)
ticker.history(proxy: "http://proxy.example:8080")
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
- `repaired`, when `repair: true`
- `repair_actions`, when `repair: true` and the row changed

When `repair: true`, `metadata[:repairs]` contains a per-row summary of repair
actions. Repair passes currently cover 100x currency/unit mixups, zero or
missing traded prices, bad split adjustment jumps, missing dividend adjustment,
OHLC bound violations, and dividend/capital-gain unit mixups.

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
ticker.valuation
ticker.calendar
ticker.earnings_dates
ticker.sec_filings
ticker.news(count: 10)
ticker.funds_data
```

`info` returns a flattened hash combining Yahoo quote summary modules and quote
data. Keys are snake_case symbols.

`valuation` / `get_valuation_measures` returns a `Ryfinance::Table` with:

- `metric`
- `value`
- `source`

The table is a current snapshot from structured Yahoo quote-summary modules and
includes metrics such as market cap, enterprise value, trailing and forward PE,
PEG ratio, price/sales, price/book, enterprise-value multiples, beta, EPS,
EBITDA, debt, cash, and revenue per share. Pass `as_dict: true` to return an
array of row hashes.

`earnings_dates(limit: 12, offset: 0)` returns a `Ryfinance::Table` with:

- `earnings_date`
- `eps_estimate`
- `reported_eps`
- `surprise_percent`
- `event_type`
- `timezone_short_name`

Pass `as_dict: true` to return an array of row hashes. The method returns `nil`
when Yahoo has no earnings calendar rows for the ticker. Yahoo limits a single
request to 100 rows.

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

### ETF and Mutual Fund Data

```ruby
fund = Ryfinance::Ticker.new("VTI").funds_data
fund.top_holdings
fund.sector_weightings
fund.fund_operations
```

`funds_data` returns `nil` for non-fund quote types. For ETFs and mutual funds,
it returns a `Ryfinance::FundsData` object.

Available methods:

- `quote_type`
- `fund?`
- `description`
- `fund_overview`
- `fund_operations`
- `asset_classes`
- `top_holdings`
- `equity_holdings`
- `bond_holdings`
- `bond_ratings`
- `sector_weightings`
- `to_h`

`top_holdings`, `equity_holdings`, `bond_holdings`, and `fund_operations` return
`Ryfinance::Table` objects. Asset classes, bond ratings, and sector weightings
return snake_case Ruby hashes.

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
ticker.shares
ticker.shares(as_dict: true)
ticker.shares_full(start: "2024-01-01", end: "2024-12-31")
ticker.isin
```

`shares` / `get_shares` returns a `Ryfinance::Table` with `:date` and `:shares`
columns from Yahoo's `shares_out` timeseries. Pass `as_dict: true` to return a
date-indexed hash. `shares_full` accepts the same date range keywords and always
returns a table.

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

## `Ryfinance::Market`

Market status and summary rows for Yahoo market groups.

```ruby
market = Ryfinance::Market.new("US")
market.status
market.summary
```

Supported market keys:

- `US`
- `GB`
- `ASIA`
- `EUROPE`
- `RATES`
- `COMMODITIES`
- `CURRENCIES`
- `CRYPTOCURRENCIES`

`status` returns a snake_case hash. Common keys include:

- `:status`
- `:market_state`
- `:open`
- `:close`
- `:timezone`
- `:tz`

`open` and `close` are Ruby `Time` objects. `timezone` is Yahoo's timezone hash,
and `tz` is the timezone short name when available.

`summary` returns a `Ryfinance::Table` of Yahoo market summary rows. The first
request for either `status` or `summary` fetches both endpoints and caches the
parsed values on the `Ryfinance::Market` instance.

## `Ryfinance::Calendars`

Market-wide Yahoo calendars. Constructor dates default to today through seven
days later.

```ruby
calendars = Ryfinance::Calendars.new(start: "2026-04-01", end: "2026-04-30")
```

Available methods:

- `earnings_calendar` / `get_earnings_calendar`
- `ipo_info_calendar` / `get_ipo_info_calendar`
- `economic_events_calendar` / `get_economic_events_calendar`
- `splits_calendar` / `get_splits_calendar`

All methods return `Ryfinance::Table` objects with snake_case symbol columns.
Date-like values are normalized to UTC `Time` objects.

Common options:

- `start:` override the constructor start date
- `end:` or `end_date:` override the constructor end date
- `limit:` number of rows to request; Yahoo caps a single request at 100
- `offset:` zero-based result offset
- `force:` bypass the per-instance cache
- `timeout:` HTTP timeout in seconds

`get_earnings_calendar` also accepts:

- `market_cap:` minimum intraday market cap
- `filter_most_active:` when true, intersect the query with Yahoo's most-active
  stock screen for the first page

```ruby
earnings = calendars.get_earnings_calendar(
  market_cap: 10_000_000_000,
  filter_most_active: false,
  limit: 25
)

earnings.each do |row|
  puts "#{row[:symbol]} #{row[:event_start_date]} #{row[:eps_estimate]}"
end
```

## `Ryfinance::Client`

HTTP client for Yahoo requests. Most users do not need to instantiate it unless
they are sharing a client, injecting a transport, or changing cookie/crumb
behavior.

```ruby
client = Ryfinance::Client.new(
  headers: {},
  transport: nil,
  crumb: :auto,
  cache: nil,
  cache_ttl: nil,
  retries: 1,
  retry_backoff: 0.5,
  retry_max_sleep: 5,
  proxy: nil
)

ticker = Ryfinance::Ticker.new("MSFT", client: client)
```

`crumb:` controls Yahoo cookie/crumb behavior:

- `:auto` sends normal requests first, then fetches a Yahoo cookie and crumb only
  after an authorization-style response.
- `:always` fetches and attaches a crumb before the first request.
- `false` disables crumb fetching and retry behavior.

`cache:` enables successful GET response caching when paired with a positive
`cache_ttl:`. Pass `true` to use `Ryfinance::MemoryCache`, or pass a custom
object that responds to `read(key)` and `write(key, value, expires_in:)`.

```ruby
client = Ryfinance::Client.new(cache: true, cache_ttl: 60)
client.clear_cache
```

`retries:` controls retries for transient Yahoo HTTP responses. By default the
client retries HTTP 429, 500, 502, 503, and 504 once, uses exponential
`retry_backoff:`, caps sleep at `retry_max_sleep:`, and honors `Retry-After`.

`proxy:` routes requests through an HTTP proxy. Pass a URI string, `URI` object,
or hash with `:host`, `:port`, optional `:user`, and optional `:password`.

```ruby
client = Ryfinance::Client.new(proxy: "http://user:pass@proxy.example:8080")
Ryfinance.download("MSFT", proxy: "http://proxy.example:8080")
Ryfinance::Ticker.new("MSFT").history(proxy: "http://proxy.example:8080")
```

Custom HTTP transports must implement:

```ruby
get(uri, headers:, timeout:, proxy: nil)
post(uri, headers:, body:, timeout:, proxy: nil)
```

The default `Ryfinance::NetHTTPTransport` keeps a small in-memory cookie jar so
Yahoo cookies learned while fetching a crumb are sent on later requests.

## `Ryfinance::MemoryCache`

Thread-safe in-memory cache for `Ryfinance::Client`.

```ruby
cache = Ryfinance::MemoryCache.new(max_size: 500)
cache.write("key", "value", expires_in: 60)
cache.read("key")
cache.delete("key")
cache.clear
cache.size
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

## `Ryfinance::Lookup`

Typed Yahoo instrument lookup. Each method returns a `Ryfinance::Table`.

```ruby
lookup = Ryfinance::Lookup.new("apple")
lookup.all
lookup.stock
lookup.mutualfund
lookup.etf
lookup.index
lookup.future
lookup.currency
lookup.cryptocurrency
lookup.get_stock(count: 100)
```

Available getter methods:

- `get_all(count: 25)`
- `get_stock(count: 25)`
- `get_mutualfund(count: 25)`
- `get_etf(count: 25)`
- `get_index(count: 25)`
- `get_future(count: 25)`
- `get_currency(count: 25)`
- `get_cryptocurrency(count: 25)`

Ruby tables keep `:symbol` as an explicit column instead of using it as a
DataFrame index. Pass `raise_errors: false` to return an empty table when Yahoo
returns a lookup error.

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
| `Ryfinance.Lookup("apple")` | `Ryfinance::Lookup.new("apple")` or `Ryfinance.lookup("apple")` |
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
| `get_valuation_measures`, `valuation_measures` | `valuation` |
| `get_calendar` | `calendar` |
| `get_earnings_dates` | `earnings_dates` |
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
| `get_funds_data` | `funds_data` |
| `get_options` | `options` |
| `get_news` | `news` |
| `get_shares` | `shares` |
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
