# Changelog

All notable changes to RYFinance are documented here.

## Unreleased

- Added CI and release hygiene checks.
- Added an opt-in live Yahoo WebSocket smoke test.
- Upgraded CI checkout and opted GitHub Actions into Node 24 for JavaScript actions.
- Added lazy Yahoo cookie/crumb retry handling in the HTTP client.
- Added opt-in history price repair passes through `repair: true`.
- Added capital-gain distribution adjusted-close repair coverage.
- Added opt-in GET response caching and transient HTTP retry controls.
- Added HTTP proxy support through `Ryfinance::Client`, `download`, and `Ticker#history`.
- Added threaded multi-ticker downloads and structured progress callbacks.
- Added `download(ignore_tz: true)` calendar-date normalization for daily data.
- Added yfinance-style multi-ticker download failure capture with `raise_errors:`.
- Added yfinance-style `Ticker#history(raise_errors:)` failure handling.
- Added per-ticker error aggregation to `Tickers#history`.
- Added Yahoo ticker news stream tabs through `Ticker#news`.
- Added ETF and mutual fund data through `Ticker#funds_data`.
- Added earnings calendar dates through `Ticker#earnings_dates`.
- Switched financial statement helpers to Yahoo fundamentals-timeseries with quote-summary fallback.
- Added market status through `Ryfinance::Market#status`.
- Added market-wide Yahoo calendars through `Ryfinance::Calendars`.
- Expanded opt-in live smoke coverage for chart, quote, and search endpoints.
- Expanded screener query metadata and validation.
- Documented open-ended screener enum fields and exposed restricted field helpers.
- Added shares outstanding through `Ticker#shares`.
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
