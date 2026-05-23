# frozen_string_literal: true

require "cgi"
require "json"
require "net/http"
require "time"
require "uri"

module Ryfinance
  Response = Struct.new(:code, :body, :headers, keyword_init: true)

  class NetHTTPTransport
    def initialize
      @cookies = {}
      @cookie_mutex = Mutex.new
    end

    def get(uri, headers:, timeout:)
      request = Net::HTTP::Get.new(uri)
      apply_cookies(request)
      headers.each { |key, value| request[key] = value }
      perform(uri, request, timeout)
    end

    def post(uri, headers:, body:, timeout:)
      request = Net::HTTP::Post.new(uri)
      apply_cookies(request)
      headers.each { |key, value| request[key] = value }
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)
      perform(uri, request, timeout)
    end

    private

    def apply_cookies(request)
      cookie_header = @cookie_mutex.synchronize do
        @cookies.map { |name, value| "#{name}=#{value}" }.join("; ")
      end
      request["Cookie"] = cookie_header unless cookie_header.empty?
    end

    def perform(uri, request, timeout)
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: timeout,
        read_timeout: timeout
      ) { |http| http.request(request) }
      store_cookies(response.get_fields("Set-Cookie") || [])

      Response.new(
        code: response.code.to_i,
        body: response.body.to_s,
        headers: response.each_header.to_h
      )
    end

    def store_cookies(set_cookie_headers)
      @cookie_mutex.synchronize do
        set_cookie_headers.each do |header|
          pair = header.to_s.split(";", 2).first
          name, value = pair.to_s.split("=", 2)
          next if name.to_s.empty? || value.nil?

          @cookies[name] = value
        end
      end
    end
  end

  class Client
    BASE_URL = "https://query2.finance.yahoo.com"
    QUERY1_URL = "https://query1.finance.yahoo.com"
    ROOT_URL = "https://finance.yahoo.com"

    DEFAULT_HEADERS = {
      "Accept" => "application/json,text/plain,*/*",
      "User-Agent" => "Mozilla/5.0 ryfinance/#{VERSION}"
    }.freeze
    CRUMB_URL = "https://query1.finance.yahoo.com/v1/test/getcrumb"
    CRUMB_COOKIE_URL = "https://fc.yahoo.com"
    CRUMB_RETRY_STATUSES = [401, 403, 422].freeze
    CRUMB_MODES = [:auto, :always, false].freeze
    DEFAULT_RETRY_STATUSES = [429, 500, 502, 503, 504].freeze

    attr_reader :transport, :cache

    def initialize(transport: nil, headers: {}, crumb: :auto, cache: nil, cache_ttl: nil, retries: 1, retry_backoff: 0.5, retry_max_sleep: 5, retry_statuses: DEFAULT_RETRY_STATUSES)
      raise ArgumentError, "crumb must be :auto, :always, or false" unless CRUMB_MODES.include?(crumb)
      raise ArgumentError, "retries must be zero or greater" if retries.to_i.negative?

      @transport = transport || NetHTTPTransport.new
      @headers = DEFAULT_HEADERS.merge(headers)
      @crumb_mode = crumb
      @crumb = nil
      @crumb_mutex = Mutex.new
      @cache = cache == true ? MemoryCache.new : cache
      @cache_ttl = cache_ttl
      @retries = retries.to_i
      @retry_backoff = retry_backoff.to_f
      @retry_max_sleep = retry_max_sleep.to_f
      @retry_statuses = retry_statuses.map(&:to_i)
    end

    def chart(symbol, params:, timeout: 10)
      data = get_json("/v8/finance/chart/#{escape_path(symbol)}", params: params, timeout: timeout)
      error = data.dig("chart", "error")
      raise_yahoo_error(error) if error

      result = data.dig("chart", "result")&.first
      raise NotFoundError.new("No chart data returned for #{symbol}") if result.nil?

      result
    end

    def quote(symbols, fields: nil, timeout: 10)
      params = { symbols: Array(symbols).join(",") }
      params[:fields] = Array(fields).join(",") if fields
      data = get_json("/v7/finance/quote", params: params, timeout: timeout)
      error = data.dig("quoteResponse", "error")
      raise_yahoo_error(error) if error

      data.dig("quoteResponse", "result") || []
    end

    def quote_summary(symbol, modules:, timeout: 10)
      data = get_json(
        "/v10/finance/quoteSummary/#{escape_path(symbol)}",
        params: { modules: Array(modules).join(",") },
        timeout: timeout
      )
      error = data.dig("quoteSummary", "error")
      raise_yahoo_error(error) if error

      data.dig("quoteSummary", "result")&.first || {}
    end

    def options(symbol, date: nil, timeout: 10)
      params = {}
      params[:date] = date if date
      data = get_json("/v7/finance/options/#{escape_path(symbol)}", params: params, timeout: timeout)
      error = data.dig("optionChain", "error")
      raise_yahoo_error(error) if error

      data.dig("optionChain", "result")&.first || {}
    end

    def search(query, quotes_count: 8, news_count: 8, lists_count: 0, timeout: 10)
      get_json(
        "/v1/finance/search",
        params: {
          q: query,
          quotesCount: quotes_count,
          newsCount: news_count,
          listsCount: lists_count,
          enableFuzzyQuery: false,
          quotesQueryId: "tss_match_phrase_query",
          newsQueryId: "news_cie_vespa",
          enableCb: true
        },
        timeout: timeout
      )
    end

    def lookup(query, type:, count:, timeout: 30)
      data = get_json(
        "/v1/finance/lookup",
        base: QUERY1_URL,
        params: {
          query: query,
          type: type,
          start: 0,
          count: count,
          formatted: "false",
          fetchPricingData: "true",
          lang: "en-US",
          region: "US"
        },
        timeout: timeout
      )
      error = data.dig("finance", "error")
      raise_yahoo_error(error) if error

      Array(data.dig("finance", "result", 0, "documents"))
    end

    def market_summary(region: nil, market: nil, timeout: 10)
      selected_market = market || region || "US"
      data = get_json(
        "/v6/finance/quote/marketSummary",
        base: QUERY1_URL,
        params: {
          fields: "shortName,regularMarketPrice,regularMarketChange,regularMarketChangePercent",
          formatted: false,
          lang: "en-US",
          market: selected_market
        },
        timeout: timeout
      )
      error = data.dig("marketSummaryResponse", "error")
      raise_yahoo_error(error) if error

      data.dig("marketSummaryResponse", "result") || []
    end

    def market_status(region: nil, market: nil, timeout: 10)
      selected_market = market || region || "US"
      data = get_json(
        "/v6/finance/markettime",
        base: QUERY1_URL,
        params: {
          formatted: true,
          key: "finance",
          lang: "en-US",
          market: selected_market
        },
        timeout: timeout
      )
      error = data.dig("finance", "error")
      raise_yahoo_error(error) if error

      data.dig("finance", "marketTimes", 0, "marketTime", 0) || {}
    end

    def timeseries(symbol, types:, period1:, period2:, timeout: 10)
      get_json(
        "/ws/fundamentals-timeseries/v1/finance/timeseries/#{escape_path(symbol)}",
        params: {
          symbol: symbol,
          type: Array(types).join(","),
          period1: period1,
          period2: period2
        },
        timeout: timeout
      )
    end

    def earnings_dates(symbol, limit:, offset:, timeout: 10)
      data = post_json(
        "/v1/finance/visualization",
        base: QUERY1_URL,
        params: { lang: "en-US", region: "US" },
        body: {
          "size" => limit,
          "offset" => offset,
          "query" => {
            "operator" => "eq",
            "operands" => ["ticker", symbol]
          },
          "sortField" => "startdatetime",
          "sortType" => "DESC",
          "entityIdType" => "earnings",
          "includeFields" => [
            "startdatetime",
            "timeZoneShortName",
            "epsestimate",
            "epsactual",
            "epssurprisepct",
            "eventtype"
          ]
        },
        timeout: timeout
      )

      data.dig("finance", "result", 0, "documents", 0) || {}
    end

    def calendar(calendar_type:, query:, include_fields:, sort_field:, limit:, offset:, timeout: 10)
      data = post_json(
        "/v1/finance/visualization",
        base: QUERY1_URL,
        params: { lang: "en-US", region: "US" },
        body: {
          "sortType" => "DESC",
          "entityIdType" => calendar_type,
          "sortField" => sort_field,
          "includeFields" => include_fields,
          "size" => [Integer(limit), 100].min,
          "offset" => Integer(offset),
          "query" => query
        },
        timeout: timeout
      )
      error = data.dig("finance", "error")
      raise_yahoo_error(error) if error

      data.dig("finance", "result", 0, "documents", 0) || {}
    end

    def screen_predefined(query, params: {}, timeout: 10)
      data = get_json(
        "/v1/finance/screener/predefined/saved",
        base: QUERY1_URL,
        params: default_screener_params.merge(scrIds: query).merge(params),
        timeout: timeout
      )

      data.dig("finance", "result")&.first || {}
    end

    def screen(body, params: {}, timeout: 10)
      data = post_json(
        "/v1/finance/screener",
        base: QUERY1_URL,
        params: default_screener_params.merge(params),
        body: body,
        timeout: timeout
      )

      data.dig("finance", "result")&.first || {}
    end

    def domain(type, key, timeout: 10)
      get_json(
        "/v1/finance/#{escape_path(type)}/#{escape_path(key)}",
        base: QUERY1_URL,
        params: { formatted: "true", withReturns: "true", lang: "en-US", region: "US" },
        timeout: timeout
      )
    end

    def get_json(path, base: BASE_URL, params: {}, timeout: 10)
      response = get(path, base: base, params: params, timeout: timeout)
      JSON.parse(response.body)
    rescue JSON::ParserError => error
      raise Error, "Yahoo returned invalid JSON for #{path}: #{error.message}"
    end

    def post_json(path, base: BASE_URL, params: {}, body: {}, timeout: 10)
      uri = build_uri(path, base: base, params: params)
      response = request_with_crumb_retry(:post, uri, timeout: timeout, body: body)
      raise_for_response!(response, uri)
      JSON.parse(response.body)
    rescue JSON::ParserError => error
      raise Error, "Yahoo returned invalid JSON for #{path}: #{error.message}"
    end

    def get(path, base: BASE_URL, params: {}, timeout: 10)
      uri = build_uri(path, base: base, params: params)
      cache_key = cache_key_for(:get, uri)
      cached = read_cache(cache_key)
      return cached if cached

      response = request_with_crumb_retry(:get, uri, timeout: timeout)
      raise_for_response!(response, uri)
      write_cache(cache_key, response)
      response
    end

    def clear_cache
      @cache.clear if @cache.respond_to?(:clear)
      self
    end

    private

    def request_with_crumb_retry(method, uri, timeout:, body: nil)
      request_uri = uri
      if @crumb_mode == :always
        crumb = ensure_crumb(timeout: timeout)
        request_uri = with_crumb(uri, crumb) if crumb
      end

      response = raw_request_with_retries(method, request_uri, timeout: timeout, body: body)
      return response unless should_retry_with_crumb?(response)

      crumb = ensure_crumb(timeout: timeout, refresh: true)
      return response unless crumb

      raw_request_with_retries(method, with_crumb(uri, crumb), timeout: timeout, body: body)
    end

    def raw_request_with_retries(method, uri, timeout:, body: nil)
      attempts = 0

      loop do
        response = raw_request(method, uri, timeout: timeout, body: body)
        return response unless retryable_response?(response) && attempts < @retries

        sleep retry_delay(response, attempts)
        attempts += 1
      end
    end

    def raw_request(method, uri, timeout:, body: nil)
      response =
        case method
        when :get
          @transport.get(uri, headers: @headers, timeout: timeout)
        when :post
          @transport.post(uri, headers: @headers, body: body, timeout: timeout)
        else
          raise ArgumentError, "Unsupported request method: #{method}"
        end

      normalize_transport_response(response)
    end

    def retryable_response?(response)
      @retry_statuses.include?(response.code)
    end

    def retry_delay(response, attempts)
      delay = retry_after(response) || (@retry_backoff * (2**attempts))
      return 0 if delay <= 0

      [delay, @retry_max_sleep].min
    end

    def retry_after(response)
      value = header_value(response.headers, "retry-after")
      return nil if value.to_s.empty?
      return value.to_f if value.to_s.match?(/\A\d+(\.\d+)?\z/)

      Time.httpdate(value).to_f - Time.now.to_f
    rescue ArgumentError
      nil
    end

    def header_value(headers, name)
      headers ||= {}
      headers.find { |key, _value| key.to_s.downcase == name }&.last
    end

    def should_retry_with_crumb?(response)
      return false if @crumb_mode == false
      return false unless CRUMB_RETRY_STATUSES.include?(response.code)

      @crumb.nil? || response.body.match?(/crumb|unauthorized|forbidden/i)
    end

    def ensure_crumb(timeout:, refresh: false)
      return nil if @crumb_mode == false

      @crumb_mutex.synchronize do
        @crumb = nil if refresh
        return @crumb if @crumb

        fetch_cookie_for_crumb(timeout: timeout)
        crumb = fetch_crumb(timeout: timeout)
        @crumb = crumb unless crumb.to_s.empty?
      end
    end

    def fetch_cookie_for_crumb(timeout:)
      uri = URI(CRUMB_COOKIE_URL)
      raw_request_with_retries(:get, uri, timeout: timeout)
    rescue HTTPError, Error
      nil
    end

    def fetch_crumb(timeout:)
      uri = URI(CRUMB_URL)
      response = raw_request_with_retries(:get, uri, timeout: timeout)
      raise RateLimitError.new("Yahoo crumb request was rate limited", status: response.code, body: response.body, uri: uri) if response.code == 429
      return nil unless response.code.between?(200, 299)

      crumb = response.body.to_s.strip
      return nil if crumb.empty? || crumb.match?(/Too Many Requests/i)

      crumb
    end

    def with_crumb(uri, crumb)
      params = URI.decode_www_form(uri.query.to_s)
      params.reject! { |key, _value| key == "crumb" }
      params << ["crumb", crumb]

      next_uri = uri.dup
      next_uri.query = URI.encode_www_form(params)
      next_uri
    end

    def read_cache(key)
      return nil unless cache_enabled?

      cached = @cache.read(key)
      cached && duplicate_response(cached)
    end

    def write_cache(key, response)
      return response unless cache_enabled? && response.code.between?(200, 299)

      @cache.write(key, duplicate_response(response), expires_in: @cache_ttl)
      response
    end

    def cache_enabled?
      @cache && @cache_ttl && @cache_ttl.to_f.positive?
    end

    def cache_key_for(method, uri)
      "#{method}:#{uri}"
    end

    def duplicate_response(response)
      Response.new(code: response.code.to_i, body: response.body.to_s.dup, headers: (response.headers || {}).dup)
    end

    def build_uri(path, base:, params:)
      uri = URI(path.start_with?("http") ? path : "#{base}#{path}")
      clean_params = params.reject { |_key, value| value.nil? }
      encoded = URI.encode_www_form(clean_params)
      uri.query = [uri.query, encoded].compact.reject(&:empty?).join("&")
      uri
    end

    def default_screener_params
      {
        corsDomain: "finance.yahoo.com",
        formatted: "false",
        lang: "en-US",
        region: "US"
      }
    end

    def normalize_transport_response(response)
      if response.is_a?(Response)
        Response.new(code: response.code.to_i, body: response.body.to_s, headers: response.headers || {})
      elsif response.respond_to?(:code) && response.respond_to?(:body)
        Response.new(code: response.code.to_i, body: response.body.to_s, headers: {})
      else
        Response.new(
          code: response.fetch(:code).to_i,
          body: response.fetch(:body).to_s,
          headers: response.fetch(:headers, {})
        )
      end
    end

    def raise_for_response!(response, uri)
      return response if response.code.between?(200, 299)

      error_class = response.code == 429 ? RateLimitError : HTTPError
      raise error_class.new(
        "Yahoo request failed with HTTP #{response.code}: #{uri}",
        status: response.code,
        body: response.body,
        uri: uri
      )
    end

    def raise_yahoo_error(error)
      code = error["code"]
      description = error["description"]
      klass = code.to_s.match?(/not found|invalid/i) ? NotFoundError : YahooError
      raise klass.new("Yahoo error #{code}: #{description}", code: code, description: description)
    end

    def escape_path(value)
      CGI.escape(value.to_s).tr("+", "%20")
    end
  end
end
