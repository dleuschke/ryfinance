# frozen_string_literal: true

require_relative "ryfinance/version"
require_relative "ryfinance/errors"
require_relative "ryfinance/utils"
require_relative "ryfinance/table"
require_relative "ryfinance/client"
require_relative "ryfinance/option_chain"
require_relative "ryfinance/ticker"
require_relative "ryfinance/tickers"
require_relative "ryfinance/search"
require_relative "ryfinance/market"

module Ryfinance
  module_function

  def Ticker(ticker, session: nil, client: nil)
    Ryfinance::Ticker.new(ticker, session: session, client: client)
  end

  def Tickers(tickers, session: nil, client: nil)
    Ryfinance::Tickers.new(tickers, session: session, client: client)
  end

  def ticker(ticker, session: nil, client: nil)
    Ticker(ticker, session: session, client: client)
  end

  def tickers(tickers, session: nil, client: nil)
    Tickers(tickers, session: session, client: client)
  end

  def download(tickers, session: nil, client: nil, **options)
    client ||= session || Client.new
    symbols = Utils.normalize_tickers(tickers)
    tables = symbols.each_with_object({}) do |symbol, result|
      result[symbol] = Ryfinance::Ticker.new(symbol, client: client).history(**history_options(options))
    end

    return tables.values.first if symbols.one? && !options.fetch(:multi_level_index, false)

    DownloadResult.new(tables, group_by: options.fetch(:group_by, "column"))
  end

  def search(query, session: nil, client: nil, **options)
    Search.new(query, session: session, client: client, **options).fetch
  end

  def lookup(query, session: nil, client: nil, **options)
    Search.new(query, session: session, client: client, **options).fetch
  end

  def market(region: "US", session: nil, client: nil)
    Market.new(region: region, session: session, client: client)
  end

  def screen(*)
    raise UnsupportedFeatureError, "Screener query builders are not implemented yet"
  end

  def enable_debug_mode
    warn "Ryfinance debug mode is controlled by your own logger/HTTP transport."
    true
  end

  def set_tz_cache_location(_path)
    warn "Ryfinance does not maintain a timezone cache."
    nil
  end

  def history_options(options)
    ignored = %i[
      threads ignore_tz progress session multi_level_index group_by
    ]
    options.reject { |key, _value| ignored.include?(key) }
  end
  private_class_method :history_options
end

RYFinance = Ryfinance unless defined?(RYFinance)
