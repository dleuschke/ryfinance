# frozen_string_literal: true

require "cgi"
require "json"
require "net/http"
require "uri"

module Ryfinance
  Response = Struct.new(:code, :body, :headers, keyword_init: true)

  class NetHTTPTransport
    def get(uri, headers:, timeout:)
      request = Net::HTTP::Get.new(uri)
      headers.each { |key, value| request[key] = value }
      perform(uri, request, timeout)
    end

    def post(uri, headers:, body:, timeout:)
      request = Net::HTTP::Post.new(uri)
      headers.each { |key, value| request[key] = value }
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)
      perform(uri, request, timeout)
    end

    private

    def perform(uri, request, timeout)
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: timeout,
        read_timeout: timeout
      ) { |http| http.request(request) }

      Response.new(
        code: response.code.to_i,
        body: response.body.to_s,
        headers: response.each_header.to_h
      )
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

    attr_reader :transport

    def initialize(transport: nil, headers: {})
      @transport = transport || NetHTTPTransport.new
      @headers = DEFAULT_HEADERS.merge(headers)
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

    def market_summary(region: "US", timeout: 10)
      get_json(
        "/v6/finance/quote/marketSummary",
        base: QUERY1_URL,
        params: { region: region },
        timeout: timeout
      ).dig("marketSummaryResponse", "result") || []
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

    def get_json(path, base: BASE_URL, params: {}, timeout: 10)
      response = get(path, base: base, params: params, timeout: timeout)
      JSON.parse(response.body)
    rescue JSON::ParserError => error
      raise Error, "Yahoo returned invalid JSON for #{path}: #{error.message}"
    end

    def post_json(path, base: BASE_URL, params: {}, body: {}, timeout: 10)
      uri = build_uri(path, base: base, params: params)
      response = normalize_response(@transport.post(uri, headers: @headers, body: body, timeout: timeout), uri)
      JSON.parse(response.body)
    rescue JSON::ParserError => error
      raise Error, "Yahoo returned invalid JSON for #{path}: #{error.message}"
    end

    def get(path, base: BASE_URL, params: {}, timeout: 10)
      uri = build_uri(path, base: base, params: params)
      normalize_response(@transport.get(uri, headers: @headers, timeout: timeout), uri)
    end

    private

    def build_uri(path, base:, params:)
      uri = URI(path.start_with?("http") ? path : "#{base}#{path}")
      clean_params = params.reject { |_key, value| value.nil? }
      encoded = URI.encode_www_form(clean_params)
      uri.query = [uri.query, encoded].compact.reject(&:empty?).join("&")
      uri
    end

    def normalize_response(response, uri)
      normalized =
        if response.is_a?(Response)
          response
        elsif response.respond_to?(:code) && response.respond_to?(:body)
          Response.new(code: response.code.to_i, body: response.body.to_s, headers: {})
        else
          Response.new(
            code: response.fetch(:code).to_i,
            body: response.fetch(:body).to_s,
            headers: response.fetch(:headers, {})
          )
        end

      return normalized if normalized.code.between?(200, 299)

      error_class = normalized.code == 429 ? RateLimitError : HTTPError
      raise error_class.new(
        "Yahoo request failed with HTTP #{normalized.code}: #{uri}",
        status: normalized.code,
        body: normalized.body,
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

