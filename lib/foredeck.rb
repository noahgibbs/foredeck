require "foredeck/version"

module Foredeck; end

require "foredeck/universe"

class Foredeck::GameState
    attr_reader :known_stars

    def initialize
        @known_stars = []
        @deck = []
    end

    def discover_stars(*stars)
        @known_stars.concat(stars)
        @known_stars.uniq!
    end
end

class Foredeck::Round
    def initialize(state, event)
        @state = state
        @event = event

        @progress = 0
        @done_progress = 100
    end

    def finished?
        @progress >= @done_progress
    end

    def add_progress(amt)
        @progress += amt
    end
end

Foredeck::Card = Struct.new("Foredeck::Card", :symbol, :desc, :energy)
[
    [:DoTheWork,            1, "Make 5 progress."],
    [:Brilliance,           2, "If your current progress is a multiple of 10, add 25."],
    [:DistractedScout,      2, "If your current progress is a multiple of 20, reset it to 0 and scout a new planet."],
    [:ScienceMarchesOn,     2, "Turn 10 progress into 1 science point."],
    [:Organization,         1, "Block 15 chaos."],
]
