require './aircraft.rb'

# The main class for the application. Manages overall aspects of the simulation.
class Simulation

  attr_accessor :future_arrivals, # A list of generated arrivals
                :landing_queue,   # The queue of aircraft that are ready to land. Some may be circling
                :landing_zone,    # The aircraft on the runway that are approaching the simulation exit
                :sim_time         # The current simulation time in seconds

  # Sets up the simulation
  # @param [Integer] arrival_count The number of arrivals to generate for the simulation
  def initialize(arrival_count=10)
    @sim_time = 0
    @circling_queue = []
    @landing_queue = []
    @landing_zone = []
    @future_arrivals = []

    # Generate a given number of arrivals to process, and sort the list based on arrival time
    arrival_count.times do
      @future_arrivals << Aircraft.new
    end
    @future_arrivals.sort{ |left, right| left.arrival_time <=> right.arrival_time }
  end

  # Adds any new arrivals at the current time to the landing queue
  def process_arrivals
    # Move any new arrivals from the future arrivals list to end of the landing queue
    while @future_arrivals.first.arrival_time == @sim_time
      @future_arrivals.first.start_queuing
      @landing_queue << @future_arrivals.slice!(0)
    end
  end

  # Updates the landing queue state
  def process_circling
    # Decrement the circling time for everyone who is already in the queue
    @circling_queue.each { |aircraft| aircraft.circle }

    # Move any aircraft that are done circling to the landing queue
    @circling_queue.each do |aircraft|
      if aircraft.is_queuing?
        @landing_queue << aircraft
      end
    end
    @circling_queue.delete_if { |aircraft| aircraft.is_queuing? }
  end

  # Updates the landing queue state
  def process_landing_queue
    # Increment queuing time for all the aircraft that are queuing
    @landing_queue.each { |aircraft| aircraft.queue }
  end

  # Updates the landing zone state
  def process_landing_zone
    # Continue processing anyone who is still in the landing zone
    @landing_zone.each { |aircraft| aircraft.land }

    # If the zone is clear, allow a new aircraft to enter
    if @landing_zone

    # For any aircraft remaining in the landing queue but:
    # * have not started circling
    # * have reached the threshold point
    # have them start circling

  end

  # Runs the simulation
  # @param [Integer] duration The amount of time to run the simulation for, in seconds
  def run(duration)
    while sim_time < duration

      process_arrivals

      process_circling

      process_landing_zone

      process_landing_queue

      # Advance the simulation time
      @sim_time += 1
    end
  end

end
