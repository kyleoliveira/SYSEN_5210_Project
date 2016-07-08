#!/usr/bin/env ruby

factor_reps = (ARGV[0] || 20).to_i
factor = (ARGV[1] || 0.05).to_f
filename = ARGV[2] || 'simulation'
reps = (ARGV[3] || 1).to_i

output_file = open("./results/summary.csv", 'w')
output_file.write '"Mean","Stdev","Run Time", "Final Done Queue", "sum(Na)", "sum(Nlq)", "sum(Nc)", "sum(Nlz)", "sum(Ntp)", "sum(Nd)", "Nlq>4", "sum(Nlq>4)"' << "\n" 

factor_reps.times do |i|
  mean_scale = (1 - factor*i).round(2)
  factor_reps.times do |j|
    sd_scale = (1 - factor*j).round(2) 
    level_cols = "\"#{mean_scale}\", \"#{sd_scale}\", "

    reps.times do |n|
      rep_filename = "./results/#{filename}_#{n.to_s.rjust(2, '0')}_#{i.to_s.rjust(2, '0')}_#{j.to_s.rjust(2, '0')}.csv" 
      line = `tail -n 2 #{rep_filename} | head -n 1`
      line.gsub!(/, \"\"/,'')
      output_file.write "#{level_cols}#{line}"
    end
    
    output_file.write "\n\n\n"
  end
end

output_file.close
