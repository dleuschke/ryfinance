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

## Differences From Python yfinance

- Ruby keyword arguments use `start:` and `end:`. `end:` is accepted even though
  Ruby reserves `end` in normal code positions.
- Returned hashes use snake_case symbol keys, for example `:regular_market_price`.
- `auto_adjust: true` adjusts OHLC values and still keeps `:adj_close` visible.
- Time values are returned as UTC `Time` objects.
- `threads`, `progress`, and `ignore_tz` are accepted by `download` for API
  familiarity but are currently ignored.
- WebSocket streaming is not implemented.
- Screener query builder classes are not implemented.
- Sector and industry domain classes are not implemented.
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

## Compatibility Roadmap

The remaining yfinance features to port are:

- WebSocket and AsyncWebSocket streaming
- Screener query builder classes
- Sector and industry domain classes
- Price repair heuristics for currency unit mixups
- Timezone cache configuration
- Optional crumb/cookie strategies for Yahoo endpoints if Yahoo tightens access

