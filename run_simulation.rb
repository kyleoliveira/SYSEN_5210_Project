#!/usr/bin/env ruby

require "#{File.expand_path(File.dirname(__FILE__))}/lib/airport_simulation.rb"

factor_reps = (ARGV[0] || 20).to_i
aircraft = (ARGV[1] || 20).to_i
factor = (ARGV[2] || 0.05).to_f
filename = ARGV[3] || 'simulation'
reps = (ARGV[4] || 1).to_i

reps.times do |n|
  factor_reps.times do |i|
    mean_scale = (1 - factor*i).round(2)
    factor_reps.times do |j|
      sd_scale = (1 - factor*j).round(2)
      rep_filename = "./results/#{filename}_#{n.to_s.rjust(2, '0')}_#{i.to_s.rjust(2, '0')}_#{j.to_s.rjust(2, '0')}.csv"

      # Run the simulation
      sim = AirportSimulation.new(aircraft, rep_filename)
      sim.run!

      # Append information about scaling to the output
      output_file = open(rep_filename, 'a')
      output_file.write "\"Scale Factor:\", \"#{mean_scale}\",  \"#{sd_scale}\", \n"
      output_file.close

      # Scale the separation standard deviation
      Aircraft::scale_separation_sd_by(sd_scale)
    end

    # Reset the standard deviation scaling for the next level
    Aircraft::reset_separation_sd

    # Scale the separation mean
    Aircraft::scale_separation_mean_by(mean_scale)
  end
  
  Aircraft::reset_separation_mean
end
