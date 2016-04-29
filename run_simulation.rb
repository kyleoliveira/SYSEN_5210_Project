#!/usr/bin/env ruby

require "#{File.expand_path(File.dirname(__FILE__))}/lib/simulation.rb"

reps = (ARGV[0] || 10).to_i
aircraft = (ARGV[1] || 10).to_i
filename = ARGV[2] || 'simulation'

reps.times do |i|
  sim = Simulation.new(aircraft, "./results/#{filename}_#{i.to_s.rjust(2, '0')}.csv")
  sim.run!
end
