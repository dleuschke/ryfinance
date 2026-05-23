# Changelog

All notable changes to RYFinance are documented here.

## Unreleased

- Added CI and release hygiene checks.
- Added an opt-in live Yahoo WebSocket smoke test.
- Added lazy Yahoo cookie/crumb retry handling in the HTTP client.
- Added opt-in history price repair passes through `repair: true`.
- Added opt-in GET response caching and transient HTTP retry controls.
- Added ETF and mutual fund data through `Ticker#funds_data`.
- Added earnings calendar dates through `Ticker#earnings_dates`.
- Added typed instrument lookup through `Ryfinance::Lookup`.
- Added valuation snapshot data through `Ticker#valuation`.
- Fixed CI dependency resolution on Ruby 3.1 by constraining async runtime and test dependencies.

## 0.3.0 - 2026-05-23

- Added Yahoo live pricing streams through `Ryfinance::WebSocket` and
  `Ryfinance::AsyncWebSocket`.
- Added `Ticker#live` and `Tickers#live` helpers.
- Added Ruby-first aliases for financial statements and shares outstanding.
- Reframed public documentation around the canonical Ruby API and documented
  yfinance-shaped names as compatibility aliases.

## 0.2.0 - 2026-05-23

- Added predefined and custom Yahoo screeners.
- Added sector and industry APIs.
- Added market summary and search helpers.

## 0.1.0 - 2026-05-23

- Added the initial gem scaffold.
- Added ticker history, quote info, options, corporate actions, financials, and
  multi-ticker downloads.
