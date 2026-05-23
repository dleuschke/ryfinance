# yfinance Compatibility

RYFinance aims to make Ruby code feel familiar to Python `yfinance` users while
staying idiomatic in Ruby.

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
msft = Ryfinance.Ticker("MSFT")
hist = msft.history(period: "1mo")
```

Ruby also supports direct class construction:

```ruby
msft = Ryfinance::Ticker.new("MSFT")
```

## DataFrame Replacement

yfinance returns Pandas `DataFrame` and `Series` objects. RYFinance returns
`Ryfinance::Table` objects or hashes.

| yfinance concept | RYFinance equivalent |
| --- | --- |
| `DataFrame` | `Ryfinance::Table` |
| `Series` | `Ryfinance::Table` with one value column |
| MultiIndex download | `Ryfinance::DownloadResult` |
| `df.to_csv()` | `table.to_csv` |
| `df.to_dict()` | `table.to_a` or `table.to_h` |

## Implemented API Surface

Core:

- `Ticker`
- `Tickers`
- `download`
- `Search`
- `Market#summary`
- `Sector`
- `Industry`
- `EquityQuery`
- `FundQuery`
- `ETFQuery`
- `screen`
- `set_tz_cache_location`
- `WebSocket`
- `AsyncWebSocket`

Ticker stock data:

- `history`
- `get_history_metadata` / `history_metadata`
- `get_dividends` / `dividends`
- `get_splits` / `splits`
- `get_capital_gains` / `capital_gains`
- `get_actions` / `actions`
- `get_shares_full`

Ticker quote data:

- `get_info` / `info`
- `get_fast_info` / `fast_info`
- `get_news` / `news`
- `get_isin` / `isin`

Ticker financials and analysis:

- `calendar`
- `sec_filings`
- `recommendations`
- `recommendations_summary`
- `upgrades_downgrades`
- `analyst_price_targets`
- `earnings_estimate`
- `revenue_estimate`
- `earnings_history`
- `eps_trend`
- `eps_revisions`
- `growth_estimates`
- `sustainability`
- `major_holders`
- `institutional_holders`
- `mutualfund_holders`
- `insider_transactions`
- `insider_roster_holders`
- `insider_purchases`
- `income_stmt`
- `quarterly_income_stmt`
- `ttm_income_stmt`
- `balance_sheet`
- `quarterly_balance_sheet`
- `cash_flow`
- `quarterly_cash_flow`
- `ttm_cash_flow`
- `earnings`
- `quarterly_earnings`

Options:

- `options`
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
- Time values are returned as UTC `Time` objects.
- `threads`, `progress`, and `ignore_tz` are accepted by `download` for API
  familiarity but are currently ignored.
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
chain = Ryfinance.Ticker("MSFT").option_chain("2026-01-16")
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
msft = Ryfinance.Ticker("MSFT")
msft.balance_sheet
msft.quarterly_income_stmt
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
technology = Ryfinance.Sector("technology")
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

- Price repair heuristics for currency unit mixups
- Optional crumb/cookie strategies for Yahoo endpoints if Yahoo tightens access
