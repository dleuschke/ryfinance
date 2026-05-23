# frozen_string_literal: true

module Ryfinance
  class Lookup
    LOOKUP_TYPES = {
      all: "all",
      stock: "equity",
      mutualfund: "mutualfund",
      etf: "etf",
      index: "index",
      future: "future",
      currency: "currency",
      cryptocurrency: "cryptocurrency"
    }.freeze

    attr_reader :query

    def initialize(query, session: nil, client: nil, timeout: 30, raise_errors: true)
      @query = query.to_s
      @client = client || session || Client.new
      @timeout = timeout
      @raise_errors = raise_errors
      @cache = {}
    end

    def all
      get_all
    end

    def stock
      get_stock
    end

    def mutualfund
      get_mutualfund
    end

    def etf
      get_etf
    end

    def index
      get_index
    end

    def future
      get_future
    end

    def currency
      get_currency
    end

    def cryptocurrency
      get_cryptocurrency
    end

    def get_all(count: 25)
      get_data(:all, count: count)
    end

    def get_stock(count: 25)
      get_data(:stock, count: count)
    end

    def get_mutualfund(count: 25)
      get_data(:mutualfund, count: count)
    end

    def get_etf(count: 25)
      get_data(:etf, count: count)
    end

    def get_index(count: 25)
      get_data(:index, count: count)
    end

    def get_future(count: 25)
      get_data(:future, count: count)
    end

    def get_currency(count: 25)
      get_data(:currency, count: count)
    end

    def get_cryptocurrency(count: 25)
      get_data(:cryptocurrency, count: count)
    end

    private

    def get_data(lookup_type, count:)
      type = LOOKUP_TYPES.fetch(lookup_type)
      count = normalize_count(count)
      cache_key = [type, count]
      @cache[cache_key] ||= fetch_table(type, count)
    end

    def fetch_table(type, count)
      rows = @client.lookup(@query, type: type, count: count, timeout: @timeout)
      table_from_documents(rows)
    rescue Error
      raise if @raise_errors

      Table.new([])
    end

    def table_from_documents(documents)
      rows = Array(documents).map { |document| Utils.deep_symbolize(Utils.unwrap_value(document)) }
      Table.new(rows)
    end

    def normalize_count(count)
      value = Integer(count)
      raise ArgumentError, "count must be greater than zero" unless value.positive?

      value
    end
  end
end
