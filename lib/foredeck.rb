require "foredeck/version"

module Foredeck; end

class Foredeck::Card
    attr :symbol

    def initialize(symbol)
        @symbol = symbol
    end

end

# The known universe, as known to player plus all AIs/rules
class Foredeck::Universe
    # Stolen somewhat arbitrarily from https://en.wikipedia.org/wiki/List_of_proper_names_of_stars
    STAR_NAME_STRINGS = File.read(__dir__ + "/foredeck/star_names.txt").split("\n").select { |s| s != "" && s[0] != "#" }
    STAR_NAME_SYMBOLS = STAR_NAME_STRINGS.map { |s| s.to_sym }
    STAR_NAMES = {}
    STAR_NAME_SYMBOLS.each.with_index { |name_sym, idx| STAR_NAMES[name_sym] = STAR_NAME_STRINGS[idx] }

    DEFAULT_COORDS = {
        width: 30,
        height: 30,
    }

    DEFAULT_FLAT_GALAXY_SHAPE = {
        min_star_dist: 4,
        max_star_conn_dist: 7,
        max_components: 1,
    }

    attr_reader :min_stars, :max_stars, :total_stars
    attr_reader :min_star_dist, :max_star_conn_dist, :max_components
    attr_reader :width, :height
    attr_reader :sectors
    attr_reader :stars

    def initialize(shape: DEFAULT_FLAT_GALAXY_SHAPE, coords: DEFAULT_COORDS, min_stars:30, max_stars:50, rand:)
        @width = coords[:width]
        @height = coords[:height]

        @rand = rand

        @min_stars = min_stars
        @max_stars = max_stars
        @total_stars = 0

        @min_star_dist = shape[:min_star_dist]
        @max_star_conn_dist = shape[:max_star_conn_dist]
        @max_components = shape[:max_components]
        @width = coords[:width]
        @height = coords[:height]

        @stars = {}

        # Distance-checking should cross no more than one complete sector. Calculate how many
        # sectors of width and of height.
        @sectors_wide  = (@width / @max_star_conn_dist.to_f).to_i
        @sectors_high  = (@height / @max_star_conn_dist.to_f).to_i
        @sector_width  = @width.to_f / @sectors_wide
        @sector_height = @height.to_f / @sectors_high
        @sectors = (1..@sectors_wide).map { (1..@sectors_high).map { [] } }

        # Track connections and components by distance - so a universe may have four components at
        # a distance of 7, but only one at a distance of 5.
        @connections = {}
        @components = {}

        gen_flat_galaxy
    end

    # Returns name symbol if added, false if not
    def try_add_new_star_blindly
        new_star_x = @rand.rand(@width)
        new_star_y = @rand.rand(@height)

        try_add_new_star_at_point(x: new_star_x, y: new_star_y)
    end

    def try_add_new_star_at_point(x:, y:, name_sym: nil)
        unless name_sym
            name_sym = (STAR_NAME_SYMBOLS - @stars.keys).sample(random: @rand)
        end

        star_sector_x = (x / @sector_width).to_i
        star_sector_y = (y / @sector_height).to_i

        min_sector_x = [star_sector_x - 1, 0].max
        max_sector_x = [star_sector_x + 1, @sectors_wide - 1].min
        min_sector_y = [star_sector_y - 1, 0].max
        max_sector_y = [star_sector_y + 1, @sectors_high - 1].min

        sector_says_no = false
        (min_sector_x..max_sector_x).each do |sector_x|
            (min_sector_y..max_sector_y).each do |sector_y|
                @sectors[sector_x][sector_y].each do |star_sym|
                    star_x = @stars[star_sym][:x]
                    star_y = @stars[star_sym][:y]
                    x_dist = star_x - x
                    y_dist = star_y - y
                    dist = Math.sqrt(x_dist.to_f * x_dist + y_dist.to_f * y_dist)
                    if dist < @min_star_dist
                        return nil
                    end
                end
            end
        end

        add_new_star(name_sym: name_sym, x: x, y: y)
        name_sym
    end

    # Based on https://stackoverflow.com/questions/13064912/generate-a-uniformly-random-point-within-an-annulus-ring
    #
    #     theta = 2 * PI * rnd();
    #     dist = sqrt(rnd()*(R1^2-R2^2)+R2^2)
    #     x = dist * cos(theta)
    #     y = dist * sin(theta)
    #
    # This instead of uniform random distance accounts for the circle getting bigger as you go outward.
    def try_add_new_stars_in_ring(from_star:, min_dist:, max_dist:, max_tries:, max_stars:)
        raise "Bad star name #{from_star.inspect}!" unless @stars[from_star]

        center_x = @stars[from_star][:x]
        center_y = @stars[from_star][:y]
        two_pi = Math::PI * 2.0
        stars_added = []

        max_tries.times do
            theta = @rand.rand(two_pi)
            dist = Math.sqrt(@rand.rand * (max_dist * max_dist - min_dist * min_dist) + min_dist * min_dist)
            x = (Math.sin(theta) * dist + center_x).to_i
            y = (Math.cos(theta) * dist + center_y).to_i

            if x < 0 || y < 0 || x >= @width || y >= @height
                # Bad location, skip
                next
            end
            res = try_add_new_star_at_point(x: x, y: y)
            stars_added.push(res) if res

            # Done, return
            return stars_added if stars_added.size >= max_stars
        end

        #STDERR.puts "Tried #{max_tries} times from #{from_star.inspect} (#{@stars[from_star][:x]}, #{@stars[from_star][:y]}), added [#{stars_added.map { |star| "#{star} (#{@stars[star][:x]}, #{@stars[star][:y]})" }.join(", ")}]"
        return nil if stars_added.empty?
        stars_added
    end

    def add_new_star(name_sym:, x:, y:)
        sector_x = (x / @sector_width).to_i
        sector_y = (y / @sector_height).to_i

        if sector_x < 0 || sector_y < 0 || sector_x >= @sectors_wide || sector_y >= @sectors_high
            raise "Trying to add star #{name_sym.inspect} at bad coordinate #{x.inspect}, #{y.inspect}!"
        end

        @stars[name_sym] = {
            symbol: name_sym,
            name: STAR_NAMES[name_sym],
            x: x,
            y: y,
        }

        @sectors[sector_x][sector_y].push name_sym
        @total_stars += 1
    end

    # Calculate galaxy shape for a flat box-shape galaxy with poisson-distant stars, fully connected
    def gen_flat_galaxy
        first_stars = (1..5).map { try_add_new_star_blindly }.compact
        raise "Error! Couldn't even add the very first star!" if first_stars.empty?

        starting_points = first_stars

        loop do
            break if starting_points.empty?
            star = starting_points.shift

            added = try_add_new_stars_in_ring(
                from_star: star,
                min_dist: @min_star_dist + 0.05,
                max_dist: @max_star_conn_dist,
                max_tries: 20,
                max_stars: [7, @max_stars - @total_stars].min)

            if added
                starting_points.concat(added)
            end

            if @total_stars >= @max_stars
                #STDERR.puts "Hit #{@total_stars} stars, breaking"
                break
            end
        end

        nil
    end

end

class Foredeck::UniverseAwareness
    def initialize(universe)
        @universe = universe
    end
end

module Foredeck
end
