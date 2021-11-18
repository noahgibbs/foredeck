#!/usr/bin/env ruby

# Foredeck CLI interface

$LOAD_PATH << "#{__dir__}/lib"

require "foredeck"
require "json"

#randomizer = Random.new(Time.now.to_i)
randomizer = Random.new(1637233196)

uni = Foredeck::Universe.new(rand: randomizer)
width = uni.width
height = uni.height

galaxy = (0..(height-1)).map { " " * width }
uni.stars.each do |star_sym, star|
    galaxy[star[:x]][star[:y]] = "*"
end
puts galaxy.join("\n")

def cli_loop
    loop do
      print "fd > "
      inp = gets
      break if inp.nil?
      break if inp.chomp == "quit"
      puts "Input was: #{inp.inspect}"
    end
end

cli_loop
puts "Foredeck - complete."
