#!/usr/bin/env ruby

require './simulation.rb'

10.times do |i|
  sim = Simulation.new(10, "simulation_#{i.to_s.rjust(2, '0')}.csv")
  sim.run!
end
