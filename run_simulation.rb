#!/usr/bin/env ruby

require './simulation.rb'

reps = (ARGV[0] || 10).to_i
filename = ARGV[1] || 'simulation'

reps.times do |i|
  sim = Simulation.new(10, "./results/#{filename}_#{i.to_s.rjust(2, '0')}.csv")
  sim.run!
end
