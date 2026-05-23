# Releasing

RYFinance releases should be boring and reproducible. Run the same checks
locally that GitHub Actions runs on pull requests and pushes to `main`.

## Preflight

```sh
bundle install
bundle exec rake ci
```

`rake ci` runs the test suite, builds the gem, and checks that release metadata
stays in sync with `Ryfinance::VERSION`.

For releases that touch Yahoo endpoint behavior, run the opt-in live smoke tests
as well:

```sh
RYFINANCE_LIVE=1 bundle exec rake test:live
```

The live smoke tests connect to Yahoo's WebSocket, chart, quote, and search
endpoints. The stream test defaults to `BTC-USD`; set `RYFINANCE_LIVE_SYMBOL` or
`RYFINANCE_LIVE_TIMEOUT` to override those values. Set
`RYFINANCE_LIVE_HTTP_SYMBOL` to override the HTTP smoke-test symbol.

## Release Steps

1. Update `lib/ryfinance/version.rb`.
2. Move relevant `CHANGELOG.md` entries from `Unreleased` under the new version.
3. Update `docs/api.md` if the public API version changed.
4. Run `bundle exec rake ci`.
5. Commit the release changes.
6. Tag the commit with `vX.Y.Z`.
7. Push the branch and tag.
8. Build and publish the gem from a clean checkout.

```sh
gem build ryfinance.gemspec
gem push ryfinance-X.Y.Z.gem
```

Do not publish a gem from a dirty working tree.
