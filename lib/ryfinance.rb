# frozen_string_literal: true

require "etc"
require "thread"

require_relative "ryfinance/version"
require_relative "ryfinance/config"
require_relative "ryfinance/errors"
require_relative "ryfinance/utils"
require_relative "ryfinance/cache"
require_relative "ryfinance/table"
require_relative "ryfinance/client"
require_relative "ryfinance/option_chain"
require_relative "ryfinance/funds_data"
require_relative "ryfinance/ticker"
require_relative "ryfinance/tickers"
require_relative "ryfinance/search"
require_relative "ryfinance/lookup"
require_relative "ryfinance/market"
require_relative "ryfinance/calendars"
require_relative "ryfinance/screener"
require_relative "ryfinance/domain"
require_relative "ryfinance/live"

module Ryfinance
  module_function

  def Ticker(ticker, session: nil, client: nil, proxy: nil)
    Ryfinance::Ticker.new(ticker, session: session, client: client, proxy: proxy)
  end

  def Tickers(tickers, session: nil, client: nil, proxy: nil)
    Ryfinance::Tickers.new(tickers, session: session, client: client, proxy: proxy)
  end

  def ticker(ticker, session: nil, client: nil, proxy: nil)
    Ticker(ticker, session: session, client: client, proxy: proxy)
  end

  def tickers(tickers, session: nil, client: nil, proxy: nil)
    Tickers(tickers, session: session, client: client, proxy: proxy)
  end

  def download(tickers, session: nil, client: nil, proxy: nil, threads: true, progress: false, **options)
    client ||= session || Client.new(proxy: proxy)
    symbols = Utils.normalize_tickers(tickers)
    tables = download_tables(symbols, client: client, proxy: proxy, threads: threads, progress: progress, options: options)

    return tables.values.first if symbols.one? && !options.fetch(:multi_level_index, false)

    DownloadResult.new(tables, group_by: options.fetch(:group_by, "column"))
  end

  def search(query, session: nil, client: nil, **options)
    Search.new(query, session: session, client: client, **options).fetch
  end

  def lookup(query, session: nil, client: nil, **options)
    Lookup.new(query, session: session, client: client, **options)
  end

  def Lookup(query, session: nil, client: nil, **options)
    Ryfinance::Lookup.new(query, session: session, client: client, **options)
  end

  def market(market = nil, region: "US", session: nil, client: nil, timeout: 30)
    Market(market || region, session: session, client: client, timeout: timeout)
  end

  def Market(market = "US", session: nil, client: nil, timeout: 30)
    Ryfinance::Market.new(market, session: session, client: client, timeout: timeout)
  end

  def calendars(start: nil, end_date: nil, session: nil, client: nil, **options)
    Calendars.new(start: start, end_date: end_date, session: session, client: client, **options)
  end

  def Calendars(start: nil, end_date: nil, session: nil, client: nil, **options)
    Ryfinance::Calendars.new(start: start, end_date: end_date, session: session, client: client, **options)
  end

  def WebSocket(**options)
    Ryfinance::WebSocket.new(**options)
  end

  def AsyncWebSocket(**options)
    Ryfinance::AsyncWebSocket.new(**options)
  end

  def sector(key, session: nil, client: nil)
    Sector.new(key, session: session, client: client)
  end

  def Sector(key, session: nil, client: nil)
    Ryfinance::Sector.new(key, session: session, client: client)
  end

  def industry(key, session: nil, client: nil)
    Industry.new(key, session: session, client: client)
  end

  def Industry(key, session: nil, client: nil)
    Ryfinance::Industry.new(key, session: session, client: client)
  end

  def screen(query, offset: nil, size: nil, count: nil, sortField: nil, sort_field: nil, sortAsc: nil, sort_asc: nil, userId: nil, user_id: nil, userIdType: nil, user_id_type: nil, session: nil, client: nil, timeout: 10)
    raise ArgumentError, "Yahoo limits query count to 250, reduce count." if count && count > 250
    raise ArgumentError, "Yahoo limits query size to 250, reduce size." if size && size > 250

    client ||= session || Client.new
    sort_field ||= sortField
    sort_asc = sortAsc if sort_asc.nil?
    user_id ||= userId
    user_id_type ||= userIdType

    if query.is_a?(String) && offset.nil?
      params = compact_screener_params(
        count: count || size,
        sortField: sort_field,
        sortAsc: sort_asc,
        userId: user_id,
        userIdType: user_id_type
      )
      return Utils.deep_symbolize(Utils.unwrap_value(client.screen_predefined(query, params: params, timeout: timeout)))
    end

    query_config = query.is_a?(String) ? predefined_query_config(query) : { "query" => query }
    query_object = query_config.fetch("query")
    raise ArgumentError, "query must be a predefined screen name or QueryBase object" unless query_object.is_a?(QueryBase)

    defaults = query.is_a?(String) ? {} : {
      "offset" => 0,
      "count" => 25,
      "sortField" => "ticker",
      "sortAsc" => false,
      "userId" => "",
      "userIdType" => "guid"
    }

    fields = defaults.merge(compact_screener_params(
      offset: offset,
      count: count,
      size: size,
      sortField: sort_field || query_config["sortField"],
      sortAsc: sort_asc.nil? ? query_config["sortType"].to_s.casecmp("asc").zero? : sort_asc,
      userId: user_id,
      userIdType: user_id_type
    ))
    fields["sortType"] = fields.delete("sortAsc") ? "ASC" : "DESC"
    fields["query"] = query_object.to_h
    fields["quoteType"] = query_object.class.quote_type

    Utils.deep_symbolize(Utils.unwrap_value(client.screen(fields, timeout: timeout)))
  end

  def enable_debug_mode
    warn "Ryfinance debug mode is controlled by your own logger/HTTP transport."
    true
  end

  def history_options(options)
    ignored = %i[
      ignore_tz session multi_level_index group_by
    ]
    options.reject { |key, _value| ignored.include?(key) }
  end
  private_class_method :history_options

  def download_tables(symbols, client:, proxy:, threads:, progress:, options:)
    tables = {}
    errors = {}
    completed = 0
    reporter = progress_reporter(progress, symbols.size)
    mutex = Mutex.new
    jobs = Queue.new
    symbols.each { |symbol| jobs << symbol }

    worker = lambda do
      loop do
        symbol = jobs.pop(true)
        begin
          table = Ryfinance::Ticker.new(symbol, client: client).history(proxy: proxy, **history_options(options))
          mutex.synchronize { tables[symbol] = table }
        rescue StandardError => error
          mutex.synchronize { errors[symbol] = error }
        ensure
          payload = mutex.synchronize do
            completed += 1
            { ticker: symbol, completed: completed, total: symbols.size, error: errors[symbol] }
          end
          reporter.call(payload)
        end
      end
    rescue ThreadError
      nil
    end

    count = download_thread_count(threads, symbols.size)
    if count > 1
      Array.new(count) { Thread.new(&worker) }.each(&:join)
    else
      worker.call
    end

    raise errors.values.first unless errors.empty?

    symbols.each_with_object({}) { |symbol, ordered| ordered[symbol] = tables[symbol] }
  end
  private_class_method :download_tables

  def download_thread_count(threads, total)
    return 1 if total <= 1 || threads == false || threads.nil?
    return [[threads.to_i, 1].max, total].min if threads.is_a?(Integer)

    [[Etc.nprocessors * 2, 1].max, total].min
  end
  private_class_method :download_thread_count

  def progress_reporter(progress, total)
    return ->(_payload) {} if progress.nil? || progress == false

    if progress.respond_to?(:call)
      lambda do |payload|
        begin
          progress.call(**payload)
        rescue ArgumentError
          progress.call(payload[:ticker], payload[:completed], payload[:total])
        end
      end
    elsif progress == true
      lambda do |payload|
        status = payload[:error] ? "failed" : "completed"
        warn "RYFinance download #{status} #{payload[:completed]}/#{total}: #{payload[:ticker]}"
      end
    else
      ->(_payload) {}
    end
  end
  private_class_method :progress_reporter

  def compact_screener_params(params)
    params.reject { |_key, value| value.nil? }
          .transform_keys { |key| key.to_s }
  end
  private_class_method :compact_screener_params

  def predefined_query_config(name)
    PREDEFINED_SCREENER_QUERIES.fetch(name) do
      raise ArgumentError, "unknown predefined screen `#{name}`"
    end
  end
  private_class_method :predefined_query_config
end

RYFinance = Ryfinance unless defined?(RYFinance)
