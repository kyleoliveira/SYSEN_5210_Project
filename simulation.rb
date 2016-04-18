require './aircraft.rb'

# The main class for the application. Manages overall aspects of the simulation.
class Simulation

  attr_accessor :future_arrivals, # A list of generated arrivals
                :approaching_queue, # The queue of aircraft that have made initial contact and approaching the landing queue
                :landing_queue,   # The queue of aircraft that are ready to land
                :circling_queue,  # The queue of aircraft that are currently circling
                :landing_zone,    # The aircraft on the runway that are approaching the simulation exit
                :done_queue,      # The aircraft that have successfully left the simulation
                :sim_time         # The current simulation time in seconds

  # Sets up the simulation
  # @param [Integer] arrival_count The number of arrivals to generate for the simulation
  def initialize(arrival_count=10, filename='simulation.out')
    @output_file = open(filename, 'w')

    @sim_time = 0
    @approaching_queue = []
    @circling_queue = []
    @landing_queue = []
    @landing_zone = []
    @done_queue = []
    @future_arrivals = []

    # Generate a given number of arrivals to process, and sort the list based on arrival time
    arrival_count.times do
      @future_arrivals << Aircraft.new
    end
    @future_arrivals.sort!{ |left, right| left.arrival_time.to_i <=> right.arrival_time.to_i }
  end

  def print_update
    @output_file.write "\nFEL: #{future_arrivals.length}, Na: #{approaching_queue.length}, " <<
                          "Nq: #{landing_queue.length}, Nc: #{circling_queue.length}, " <<
                          "Nl: #{landing_zone.length}, Nd: #{done_queue.length}\n"
  end

  # Adds any new arrivals at the current time to the landing queue
  def process_arrivals
    # Move any new arrivals from the future arrivals list to end of the landing queue
    while future_arrivals.length > 0 && future_arrivals.first.arrival_time == sim_time
      future_arrivals.first.approach!
      approaching_queue << future_arrivals.slice!(0)
      @output_file.write "\n#{approaching_queue.last.flight_number} (#{approaching_queue.last.type}) made contact at T=#{sim_time}, ETA=T+#{approaching_queue.last.approaching_time}\n"
      print_update
    end
  end

  # Updates the landing queue state
  def process_approaching
    # Update the approaching aircrafts' status
    approaching_queue.each { |aircraft| aircraft.approach! if aircraft.may_approach? }

    # Transition any aircraft that are ready to do so
    while approaching_queue.length > 0 && approaching_queue.first.may_start_queuing?
      approaching_queue.first.start_queuing!(landing_queue.last)
      landing_queue << approaching_queue.slice!(0)
      @output_file.write "\n#{landing_queue.last.flight_number} (#{landing_queue.last.type}) entering the landing queue at T=#{sim_time} " <<
                             "with separation=#{landing_queue.last.queuing_time}\n"
      print_update
    end
  end

  # Updates the landing queue state
  def process_circling
    # Update the circling aircrafts' status
    circling_queue.each { |aircraft| aircraft.circle! if aircraft.may_circle? }

    # Transition any aircraft that are ready to do so
    while circling_queue.length > 0 && circling_queue.first.may_start_queuing?
      circling_queue.first.start_queuing!(landing_queue.last)
      landing_queue << circling_queue.slice!(0)
      @output_file.write "\n#{landing_queue.last.flight_number} (#{landing_queue.last.type}) reentering the landing queue at T=#{sim_time} " <<
                             "with separation=#{landing_queue.last.queuing_time}\n"
      print_update
    end
  end

  # Updates the landing queue state
  def process_queuing
    # Update the queued aircrafts' status
    landing_queue.each { |aircraft| aircraft.queue! if aircraft.may_queue? }

    # Transition any aircraft that are ready to do so
    while landing_queue.length > 0 && landing_zone.length == 0 && landing_queue.first.may_start_landing?
      landing_queue.first.start_landing!
      landing_zone << landing_queue.slice!(0)
      @output_file.write "\n#{landing_zone.last.flight_number} (#{landing_zone.last.type}) landing at T=#{sim_time}, " <<
                             "ETA=T+#{landing_zone.last.landing_time}\n"
      print_update
    end

    # Any other aircraft that are ready to land must circle if the landing zone is occupied
    while landing_queue.length > 0 && landing_zone.length == 1 && landing_queue.first.may_start_circling?
      landing_queue.first.start_circling!
      circling_queue << landing_queue.slice!(0)
      @output_file.write "\n#{circling_queue.last.flight_number} (#{circling_queue.last.type}) circling back around at T=#{sim_time}, " <<
                             "returning to landing queue at T+#{circling_queue.last.circling_time}\n"
      print_update
    end

  end

  # Updates the landing zone state
  def process_landing_zone
    # Update the status of the aircraft already in the landing zone
    landing_zone.each { |aircraft| aircraft.land! if aircraft.may_land? }

    # Transition any aircraft that are ready to do so
    while landing_zone.length > 0 && landing_zone.first.may_finish?
      landing_zone.first.finish!
      done_queue << landing_zone.slice!(0)
      @output_file.write "\n#{done_queue.last.flight_number} (#{done_queue.last.type}) finished at T=#{sim_time}\n"
      print_update
    end
  end

  def all_aircraft_processed?
    future_arrivals == 0 && approaching_queue.length == 0 &&
      landing_queue.length == 0 && circling_queue.length == 0 &&
      landing_zone.length == 0
  end

  # Runs the simulation
  # @param [Integer] duration The amount of time to run the simulation for, in seconds
  def run!(duration=-1)

    # Run until the duration is reached or there are no more aircraft to process.
    # If no duration is provided, simply continue until processing is complete.
    while (sim_time < duration || duration < 0) && !all_aircraft_processed?

      process_arrivals

      process_circling

      process_approaching

      process_landing_zone

      process_queuing

      # Advance the simulation time
      @output_file.write '.'
      @sim_time += 1
    end

    @output_file.write "Simulation complete at #{sim_time}\n"

    # Close the file since we're done writing it.
    @output_file.close
  end

end
