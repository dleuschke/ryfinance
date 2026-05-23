# yfinance Compatibility

RYFinance keeps enough yfinance-shaped API surface to make migration easy, but
the canonical API is Ruby-first. Prefer direct class construction, lowercase
module helpers, snake_case keyword arguments, block callbacks, and
`Ryfinance::Table` objects in new Ruby code.

## Naming

Python:

```python
import yfinance as yf
msft = yf.Ticker("MSFT")
hist = msft.history(period="1mo")
```

Ruby:

```ruby
require "ryfinance"
msft = Ryfinance::Ticker.new("MSFT")
hist = msft.history(period: "1mo")
```

For line-by-line ports, RYFinance also keeps yfinance-style constructor shims:

```ruby
msft = Ryfinance.Ticker("MSFT")
```

## DataFrame Replacement

yfinance returns Pandas `DataFrame` and `Series` objects. RYFinance returns
`Ryfinance::Table` objects or hashes.

| yfinance concept | RYFinance equivalent |
| --- | --- |
| `DataFrame` | `Ryfinance::Table` |
| `Series` | `Ryfinance::Table` with one value column |
| MultiIndex download | `Ryfinance::DownloadResult` |
| `FundsData` DataFrames | `Ryfinance::FundsData` methods returning `Ryfinance::Table` |
| `df.to_csv()` | `table.to_csv` |
| `df.to_dict()` | `table.to_a` or `table.to_h` |

## Compatibility Surface

The full canonical API is documented in [api.md](api.md). The yfinance-oriented
compatibility layer includes:

Core constructor and module shims:

- `Ryfinance.Ticker`
- `Ryfinance.Tickers`
- `Ryfinance.Lookup`
- `Ryfinance.Market`
- `Ryfinance.Calendars`
- `Ryfinance.Sector`
- `Ryfinance.Industry`
- `Ryfinance.WebSocket`
- `Ryfinance.AsyncWebSocket`
- `download`
- `lookup`
- `screen`
- `EquityQuery`
- `FundQuery`
- `ETFQuery`
- `set_tz_cache_location`

Market:

- `Market#status`
- `Market#summary`
- `Ryfinance.Market`
- `Ryfinance.market`

Calendars:

- `Calendars#get_earnings_calendar` / `Calendars#earnings_calendar`
- `Calendars#get_ipo_info_calendar` / `Calendars#ipo_info_calendar`
- `Calendars#get_economic_events_calendar` / `Calendars#economic_events_calendar`
- `Calendars#get_splits_calendar` / `Calendars#splits_calendar`
- `Ryfinance.Calendars`
- `Ryfinance.calendars`

Ticker stock data:

- `history`
- `get_history_metadata` / `history_metadata`
- `get_dividends` / `dividends`
- `get_splits` / `splits`
- `get_capital_gains` / `capital_gains`
- `get_actions` / `actions`
- `get_shares` / `shares`
- `get_shares_full` / `shares_full`

Ticker quote data:

- `get_info` / `info`
- `get_fast_info` / `fast_info`
- `get_valuation_measures` / `valuation`
- `get_news` / `news`
- `get_isin` / `isin`
- `get_earnings_dates` / `earnings_dates`

Ticker financials and analysis:

- `get_calendar` / `calendar`
- `get_sec_filings` / `sec_filings`
- `get_recommendations` / `recommendations`
- `get_recommendations_summary` / `recommendations_summary`
- `get_upgrades_downgrades` / `upgrades_downgrades`
- `get_analyst_price_targets` / `analyst_price_targets`
- `get_earnings_estimate` / `earnings_estimate`
- `get_revenue_estimate` / `revenue_estimate`
- `get_earnings_history` / `earnings_history`
- `get_eps_trend` / `eps_trend`
- `get_eps_revisions` / `eps_revisions`
- `get_growth_estimates` / `growth_estimates`
- `get_sustainability` / `sustainability`
- `get_major_holders` / `major_holders`
- `get_institutional_holders` / `institutional_holders`
- `get_mutualfund_holders` / `mutualfund_holders`
- `get_insider_transactions` / `insider_transactions`
- `get_insider_roster_holders` / `insider_roster_holders`
- `get_insider_purchases` / `insider_purchases`
- `get_funds_data` / `funds_data`
- `get_income_stmt` / `income_statement`
- `get_balance_sheet` / `balance_sheet`
- `get_cash_flow` / `cash_flow`
- `get_earnings` / `earnings`
- `income_stmt`, `quarterly_income_stmt`, and `ttm_income_stmt`

Options:

- `get_options` / `options`
- `option_chain`

Sector and industry data:

- `Sector#name`
- `Sector#symbol`
- `Sector#ticker`
- `Sector#overview`
- `Sector#top_companies`
- `Sector#research_reports`
- `Sector#top_etfs`
- `Sector#top_mutual_funds`
- `Sector#industries`
- `Industry#name`
- `Industry#symbol`
- `Industry#ticker`
- `Industry#overview`
- `Industry#top_companies`
- `Industry#research_reports`
- `Industry#sector_key`
- `Industry#sector_name`
- `Industry#top_growth_companies`
- `Industry#top_performing_companies`

Screeners:

- `PREDEFINED_SCREENER_QUERIES`
- `EquityQuery`
- `FundQuery`
- `ETFQuery`
- `screen`

Query builders validate Yahoo field names, restricted enum values, and numeric
comparisons before requests are sent. `is-in` serializes as yfinance's `OR` of
`EQ` queries. Very large Yahoo enum families such as industry, fund category,
and fund family are treated as open-ended instead of partially validated.

Lookup:

- `Lookup#get_all` / `Lookup#all`
- `Lookup#get_stock` / `Lookup#stock`
- `Lookup#get_mutualfund` / `Lookup#mutualfund`
- `Lookup#get_etf` / `Lookup#etf`
- `Lookup#get_index` / `Lookup#index`
- `Lookup#get_future` / `Lookup#future`
- `Lookup#get_currency` / `Lookup#currency`
- `Lookup#get_cryptocurrency` / `Lookup#cryptocurrency`

Live streaming:

- `WebSocket#subscribe`
- `WebSocket#unsubscribe`
- `WebSocket#listen`
- `WebSocket#close`
- `AsyncWebSocket#subscribe`
- `AsyncWebSocket#unsubscribe`
- `AsyncWebSocket#listen`
- `AsyncWebSocket#close`
- `Ryfinance.WebSocket`
- `Ryfinance.AsyncWebSocket`
- `Ticker#live`
- `Tickers#live`

## Differences From Python yfinance

- Ruby keyword arguments use `start:` and `end:`. `end:` is accepted even though
  Ruby reserves `end` in normal code positions.
- Returned hashes use snake_case symbol keys, for example `:regular_market_price`.
- `auto_adjust: true` adjusts OHLC values and still keeps `:adj_close` visible.
- `repair: true` runs yfinance-style repair passes and adds `:repaired` /
  `:repair_actions` columns plus `metadata[:repairs]`; yfinance exposes this as
  a `Repaired?` column.
- `Ticker#history` follows yfinance's non-raising default for Yahoo-side
  failures and returns an empty table with `metadata[:error]`. Pass
  `raise_errors: true` for strict behavior.
- `Tickers#history` returns a `DownloadResult` with the same per-ticker
  `errors`, `failed_tickers`, and `successful_tickers` helpers as `download`.
- Time values are returned as UTC `Time` objects.
- `download` honors `threads:` for concurrent multi-ticker requests and
  `progress:` for per-ticker completion events. Like yfinance, batch downloads
  keep successful tickers when one symbol fails; failed symbols get empty tables
  with `metadata[:error]`, and `DownloadResult#errors` exposes the captured
  exceptions. Pass `raise_errors: true` for strict behavior. `ignore_tz: true`
  converts daily and larger interval download row dates to Ruby `Date` values;
  intraday rows remain explicit UTC `Time` values because Ruby does not have a
  timezone-naive `Time` type.
- Top-level `Ryfinance.Ticker(...)` and similar capitalized module methods are
  compatibility shims. Prefer `Ryfinance::Ticker.new(...)` in new Ruby code.
- `Ticker#funds_data` returns `nil` for non-fund quote types. For ETFs and
  mutual funds it returns a Ruby `Ryfinance::FundsData` object with table and
  hash helpers instead of Pandas DataFrames.
- `Ticker#earnings_dates` returns a `Ryfinance::Table` with an explicit
  `:earnings_date` column instead of a Pandas datetime index. It accepts
  `limit:`, `offset:`, and `as_dict:`.
- Financial statement helpers prefer Yahoo's fundamentals-timeseries endpoint,
  matching yfinance's financials source, and fall back to quote-summary modules
  for symbols without timeseries rows.
- `Lookup` methods return `Ryfinance::Table` objects with `:symbol` as an
  ordinary column instead of a Pandas index.
- `Market#summary` returns a `Ryfinance::Table` instead of yfinance's
  exchange-keyed dictionary. `Market#status` returns a snake_case hash with
  Ruby `Time` objects for `:open` and `:close`; `:tz` is the timezone short name
  rather than Python's timezone object.
- `Ticker#shares` returns Yahoo `shares_out` timeseries rows as a
  `Ryfinance::Table`. The current Python yfinance internals expose
  `get_shares`, but the fundamentals-backed scraper may raise a not-implemented
  exception for that dataset.
- `Ticker#news` uses Yahoo's ticker news stream with the same `tab:` values as
  yfinance: `"news"`, `"all"`, and `"press releases"`. Returned article keys are
  snake_case symbols.
- `Ticker#valuation` returns a current `Ryfinance::Table` snapshot from Yahoo's
  structured quote-summary data. yfinance's `get_valuation_measures` scrapes the
  key-statistics page and may expose historical columns when Yahoo renders them.
- `Calendars` returns `Ryfinance::Table` objects instead of Pandas DataFrames.
  It accepts `end:` as a compatibility keyword, while `end_date:` is also
  available for Ruby code that avoids reserved-word-shaped names.
- Yahoo cookie/crumb handling is lazy by default. RYFinance fetches a crumb only
  after Yahoo responds as though one is required; yfinance generally manages
  cookie and crumb state before making protected requests.
- GET response caching is exposed through `Ryfinance::Client` instead of
  accepting a Python `requests_cache` session.
- `Ryfinance::Client` retries transient HTTP 429 and 5xx responses by default.
- Proxy support is exposed through `Ryfinance::Client.new(proxy:)`, plus
  yfinance-shaped `proxy:` keywords on `download` and `Ticker#history`.
- `AsyncWebSocket` follows Ruby's `async` gem conventions instead of Python's
  `async` / `await` syntax.
- Screener query field coverage is focused on common Yahoo fields and the
  predefined screens; custom field names can still be sent through query objects.
- `isin` does not scrape third party websites. It only returns an ISIN if Yahoo
  provides one in quote data.

## Porting Examples

### Download Prices

Python:

```python
import yfinance as yf
data = yf.download("MSFT AAPL", period="1y")
```

Ruby:

```ruby
data = Ryfinance.download("MSFT AAPL", period: "1y")
data["MSFT"][:close]
```

### Options Chain

Python:

```python
chain = yf.Ticker("MSFT").option_chain("2026-01-16")
chain.calls
```

Ruby:

```ruby
chain = Ryfinance::Ticker.new("MSFT").option_chain("2026-01-16")
chain.calls
```

### Financial Statements

Python:

```python
msft = yf.Ticker("MSFT")
msft.balance_sheet
msft.quarterly_income_stmt
```

Ruby:

```ruby
msft = Ryfinance::Ticker.new("MSFT")
msft.balance_sheet
msft.quarterly_income_statement
```

### Fund Data

Python:

```python
vti = yf.Ticker("VTI")
fund = vti.funds_data
fund.top_holdings
fund.sector_weightings
```

Ruby:

```ruby
vti = Ryfinance::Ticker.new("VTI")
fund = vti.funds_data
fund.top_holdings
fund.sector_weightings
```

### Earnings Dates

Python:

```python
msft = yf.Ticker("MSFT")
dates = msft.get_earnings_dates(limit=12, offset=0)
```

Ruby:

```ruby
msft = Ryfinance::Ticker.new("MSFT")
dates = msft.earnings_dates(limit: 12, offset: 0)
dates.first[:earnings_date]
```

### Valuation Measures

Python:

```python
msft = yf.Ticker("MSFT")
valuation = msft.get_valuation_measures()
```

Ruby:

```ruby
msft = Ryfinance::Ticker.new("MSFT")
valuation = msft.valuation
valuation[:value]
```

### Lookup

Python:

```python
lookup = yf.Lookup("apple")
stocks = lookup.get_stock(count=25)
etfs = lookup.etf
```

Ruby:

```ruby
lookup = Ryfinance::Lookup.new("apple")
stocks = lookup.get_stock(count: 25)
etfs = lookup.etf
```

### Screener

Python:

```python
from yfinance import EquityQuery
q = EquityQuery("and", [
    EquityQuery("gt", ["percentchange", 3]),
    EquityQuery("eq", ["region", "us"]),
])
response = yf.screen(q, sortField="percentchange", sortAsc=True)
```

Ruby:

```ruby
query = Ryfinance::EquityQuery.new("and", [
  Ryfinance::EquityQuery.new("gt", ["percentchange", 3]),
  Ryfinance::EquityQuery.new("eq", ["region", "us"])
])
response = Ryfinance.screen(query, sort_field: "percentchange", sort_asc: true)
```

### Sector and Industry

Python:

```python
technology = yf.Sector("technology")
technology.industries
```

Ruby:

```ruby
technology = Ryfinance::Sector.new("technology")
technology.industries
```

### Live Streaming

Python:

```python
with yf.WebSocket() as ws:
    ws.subscribe(["AAPL", "BTC-USD"])
    ws.listen(lambda quote: print(quote))
```

Ruby:

```ruby
ws = Ryfinance::WebSocket.new
ws.subscribe(["AAPL", "BTC-USD"])

begin
  ws.listen { |quote| puts quote }
ensure
  ws.close
end
```

## Compatibility Roadmap

The remaining yfinance features to port are:

- Network-assisted reconstruction for longer missing price ranges and additional
  repair edge cases discovered through yfinance parity testing
