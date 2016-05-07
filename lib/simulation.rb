require "#{File.expand_path(File.dirname(__FILE__))}/aircraft.rb"
require "#{File.expand_path(File.dirname(__FILE__))}/aircraft_queue.rb"

# The main class for the application. Manages overall aspects of the simulation.
class Simulation

  attr_accessor :future_arrivals,   # A list of generated arrivals
                :approaching_queue, # The queue of aircraft that have made initial contact and approaching the landing queue
                :landing_queue,     # The queue of aircraft that are ready to land
                :circling_queue,    # The queue of aircraft that are currently circling
                :landing_zone,      # The aircraft on the runway that are approaching the simulation exit
                :done_queue,        # The aircraft that have successfully left the simulation
                :sim_time,          # The current simulation time in seconds
                :n_a,               # Number of approaches so far
                :n_lq,              # Number of aircraft that have entered the landing queue so far
                :n_c,               # Number of aircraft that have started circling so far
                :n_lz,              # Number of aircraft that have entered the landing zone so far
                :n_tp,              # Number of aircraft that have reached the threshold point so far
                :n_d                # Number of aircraft that have exited the landing zone so far

  # Sets up the simulation
  # @param [Integer] arrival_count The number of arrivals to generate for the simulation
  def initialize(arrival_count=30, filename='simulation.csv', separation_mean=nil, separation_sd=nil)
    @arrival_count = arrival_count
    @output_file = open(filename, 'w')
    # @output_file.sync = true

    @sim_time = 0
    @approaching_queue = AircraftQueue.new
    @circling_queue = AircraftQueue.new
    @landing_queue = AircraftQueue.new
    @landing_zone = AircraftQueue.new
    @done_queue = AircraftQueue.new
    @future_arrivals = AircraftQueue.new

    # Initialize the statistics of interest
    @n_a = 0
    @n_lq = 0
    @n_c = 0
    @n_lz = 0
    @n_tp = 0
    @n_d = 0
    @n_lq_gt_4 = 0
    @n_lq_gt_4_since = nil

    # This lets us update the separation mean and sd table from the default ones:
    Aircraft::separation_mean = separation_mean unless separation_mean.nil?
    Aircraft::separation_sd = separation_sd unless separation_sd.nil?

    # Generate a given number of arrivals to process, and sort the list based on arrival time
    arrival_count.times do
      @future_arrivals << Aircraft.new
    end

    # Sort the FEL by arrival time so that the first future arrival is at the front of the queue
    @future_arrivals.sort!
  end

  def print_fancy_queues_header
    "\"FEL\", " <<
    "\"Approaching\", " <<
    "\"Landing Queue\", " <<
    "\"Circling\", " <<
    "\"Landing Zone\", " <<
    "\"Done\""
  end

  def print_fancy_queues
    "\"#{Simulation::queue_to_s(@future_arrivals)}\", " <<
    "\"#{Simulation::queue_to_s(@approaching_queue)}\", " <<
    "\"#{Simulation::queue_to_s(@landing_queue)}\", " <<
    "\"#{Simulation::queue_to_s(@circling_queue)}\", " <<
    "\"#{Simulation::queue_to_s(@landing_zone)}\", " <<
    "\"#{Simulation::queue_to_s(@done_queue)}\""
  end

  # Prints the header to the output file.
  def print_header
    header_string = '"T", ' <<
                    print_fancy_queues_header << ', ' <<
                    "\"sum(Na)\", \"sum(Nlq)\", \"sum(Nc)\", " <<
                    "\"sum(Nlz)\", \"sum(Ntp)\", " <<
                    "\"sum(Nd)\", " <<
                    "\"Nlq>4\", " <<
                    "\"sum(Nlq>4)\"" <<
                    "\n"
    @output_file.write header_string
  end

  # Reports whether the number of aircraft in the landing queue is greater than 4
  # @return [TrueFalse] True if there are 5 or more aircraft in the landing queue
  def n_lq_gt_4?
    landing_queue.length > 4
  end

  # Updates the statistic tracking whether the length of the landing queue is 5 or more
  def update_queue_length_statistic
    unless @n_lq_gt_4_since.nil?
      @n_lq_gt_4 += sim_time - @n_lq_gt_4_since
    end

    if n_lq_gt_4?
      @n_lq_gt_4_since = @sim_time
    else
      @n_lq_gt_4_since = nil
    end
  end

  # Prints the current simulation state to the output file.
  def print_update
    line = "\"#{sim_time}\", " <<
           "#{print_fancy_queues}, " <<
           "\"#{n_a}\", \"#{n_lq}\", \"#{n_c}\", " <<
           "\"#{n_lz}\", \"#{n_tp}\", " <<
           "\"#{n_d}\", " <<
           "\"#{n_lq_gt_4?}\", " <<
           "\"#{@n_lq_gt_4}\"" <<
           "\n"
    @output_file.write line
  end

  # Adds any new arrivals at the current time to the landing queue
  def process_arrivals
    # Move any new arrivals from the future arrivals list to end of the landing queue
    while future_arrivals.length > 0 && future_arrivals.first.next_transition_at == sim_time
      future_arrivals.first.approach!(sim_time)
      approaching_queue << future_arrivals.slice!(0)
      approaching_queue.sort!
      @n_a += 1
      update_queue_length_statistic
      print_update
    end
  end

  # Updates the landing queue state
  def process_approaching
    # Transition any aircraft that are ready to do so
    while approaching_queue.length > 0 && approaching_queue.first.done_approaching?(sim_time)
      approaching_queue.first.queue!(landing_queue.last, sim_time)
      landing_queue << approaching_queue.slice!(0)
      @n_lq += 1
      update_queue_length_statistic
      print_update
    end
  end

  # Updates the circling queue state
  def process_circling
    # Transition any aircraft that are ready to do so
    while circling_queue.length > 0 && circling_queue.first.done_circling?(sim_time)
      circling_queue.first.requeue!(landing_queue.last, sim_time)
      landing_queue << circling_queue.slice!(0)
      print_update
      update_queue_length_statistic
    end
  end

  # Updates the landing queue state
  def process_queuing
    # Transition any aircraft that are ready to do so
    while landing_queue.length > 0 && landing_zone.length == 0 && landing_queue.first.may_land?(sim_time)
      landing_queue.first.land!(sim_time)
      landing_zone << landing_queue.slice!(0)
      @n_lz += 1
      @n_tp += 1
      update_queue_length_statistic
      print_update
    end

    # Any other aircraft that are ready to land must circle if the landing zone is occupied
    while landing_queue.length > 0 && landing_zone.length == 1 && landing_queue.first.may_circle?(sim_time)
      landing_queue.first.circle!(sim_time)
      circling_queue << landing_queue.slice!(0)
      circling_queue.sort!
      @n_c += 1
      @n_tp += 1
      update_queue_length_statistic
      print_update
    end

  end

  # Updates the landing zone state
  def process_landing_zone
    # Transition any aircraft that are ready to do so
    while landing_zone.length > 0 && landing_zone.first.may_finish?(sim_time)
      landing_zone.first.finish!(sim_time)
      done_queue << landing_zone.slice!(0)
      @n_d += 1
      update_queue_length_statistic
      print_update
    end
  end

  # Are all aircraft processed through the simulation
  # @return [TrueFalse] True if all aircraft have been processed
  def all_aircraft_processed?
    done_queue.length == @arrival_count
  end

  # A list of the times at which the next aircraft in each queue will be ready to transition.
  # @return [Array] List of times
  def next_up
    [
      (@future_arrivals.first.next_transition_at unless @future_arrivals.empty?),
      (@approaching_queue.first.next_transition_at unless @approaching_queue.empty?),
      (@circling_queue.first.next_transition_at unless @circling_queue.empty?),
      (@landing_queue.first.next_transition_at unless @landing_queue.empty?),
      (@landing_zone.first.next_transition_at unless @landing_zone.empty?)
    ]
  end

  # Calculates when the next even will occur across all queues
  # @return [Integer] The time at which the next event will occur
  # @raise [RangeError] If a jump time is selected that is in the past
  def time_jump
    nu = next_up.reject{ |n| n.nil? }
    jump_to_time = nu.empty? ? sim_time + 1 : nu.min

    msg = "We have chosen the wrong time to jump to somewhere along the way!\n#{self.inspect}"
    raise RangeError, msg if jump_to_time < @sim_time

    jump_to_time
  end

  # Runs the simulation. By providing the optional duration variable, the user can step through a given amount of time.
  # @param [Integer] duration The amount of time to run the simulation for, in seconds
  def run!(duration=-1)
    print_header

    # Run until the duration is reached or there are no more aircraft to process.
    # If no duration is provided, simply continue until processing is complete.
    while (duration < 0 || sim_time < duration) && !all_aircraft_processed?
      process_arrivals

      process_circling

      process_approaching

      process_landing_zone

      process_queuing

      # Advance the simulation time
      @sim_time = time_jump
    end

    puts "Simulation complete at #{sim_time}\n"

    # Close the file since we're done writing it.
    @output_file.close
  end

  class << self

    # Converts a queue to a string of type initials, where the head of the queue is on the right
    def queue_to_s(queue)
      queue.collect{ |a| a.type[0].upcase }.reverse.join
    end

  end

end
