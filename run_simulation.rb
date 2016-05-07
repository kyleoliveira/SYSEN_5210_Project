#!/usr/bin/env ruby

require "#{File.expand_path(File.dirname(__FILE__))}/lib/simulation.rb"

reps = (ARGV[0] || 20).to_i
aircraft = (ARGV[1] || 50).to_i
factor = (ARGV[2] || 0.05).to_f
filename = ARGV[3] || 'simulation'

reps.times do |i|
  rep_filename = "./results/#{filename}_#{i.to_s.rjust(2, '0')}.csv"

  # Run the simulation
  sim = Simulation.new(aircraft, rep_filename)
  sim.run!

  # Append information about scaling to the output
  output_file = open(rep_filename, 'a')
  output_file.write "\"Scale Factor:\", \"#{(1 - factor*i).round(2)}\"\n"
  output_file.close

  # Scale the separation mean
  Aircraft::scale_separation_mean_by((1 - factor*(i+1)).round(2))
end
