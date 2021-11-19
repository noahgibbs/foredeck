require "foredeck/version"

module Foredeck; end

require "foredeck/universe"

class Foredeck::Card
    attr :symbol

    def initialize(symbol)
        @symbol = symbol
    end

end
