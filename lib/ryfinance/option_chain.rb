# frozen_string_literal: true

module Ryfinance
  OptionChain = Struct.new(:calls, :puts, :underlying, keyword_init: true) do
    def to_h
      {
        calls: calls.to_a,
        puts: puts.to_a,
        underlying: underlying
      }
    end
  end
end

