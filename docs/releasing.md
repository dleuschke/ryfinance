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
