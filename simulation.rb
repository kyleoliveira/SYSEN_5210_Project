require './aircraft.rb'

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
  def initialize(arrival_count=10, filename='simulation.csv', separation_mean=nil, separation_sd=nil)
    @arrival_count = arrival_count
    @output_file = open(filename, 'w')
    @output_file.sync = true

    @sim_time = 0
    @approaching_queue = []
    @circling_queue = []
    @landing_queue = []
    @landing_zone = []
    @done_queue = []
    @future_arrivals = []

    # Initialize the statistics of interest
    @n_a = 0
    @n_lq = 0
    @n_c = 0
    @n_lz = 0
    @n_tp = 0
    @n_d = 0

    # This lets us update the separation mean and sd table from the default ones:
    Aircraft::separation_mean = separation_mean unless separation_mean.nil?
    Aircraft::separation_sd = separation_sd unless separation_sd.nil?

    # Generate a given number of arrivals to process, and sort the list based on arrival time
    arrival_count.times do
      @future_arrivals << Aircraft.new
    end
    @future_arrivals.sort!{ |left, right| left.arrival_time.to_i <=> right.arrival_time.to_i }
  end

  def print_header
    header_string = '"T", ' <<
                    '"FEL", "Next Contact At", ' <<
                    '"Na", "Next Landing Queue ETA", ' <<
                    '"Nq", "Next Threshold Point ETA", ' <<
                    '"Nc", "Next Circle Complete At",' <<
                    "\"Nl\", \"Next Landing Zone ETA\", " <<
                    "\"Nd\", " <<
                    "\"sum(Na)\", \"sum(Nlq)\", \"sum(Nc)\", " <<
                    "\"sum(Nlz)\", \"sum(Ntp)\", " <<
                    "\"sum(Nd)\"" <<
                    "\n"
    @output_file.write header_string
  end

  def print_update
    fel_eta = future_arrivals.length > 0 ? future_arrivals.first.arrival_time : '--'
    approach_eta = approaching_queue.length > 0 ? approaching_queue.first.approaching_time : '--'
    landing_queue_eta = landing_queue.length > 0 ? landing_queue.first.queuing_time : '--'
    circling_eta = circling_queue.length > 0 ? circling_queue.first.circling_time : '--'
    landing_zone_eta = landing_zone.length > 0 ? landing_zone.first.landing_time : '--'


    @output_file.write "\"#{sim_time}\", " <<
                       "\"#{future_arrivals.map(&:to_s).reverse}\", \"#{fel_eta}\", " <<
                       "\"#{approaching_queue.map(&:to_s).reverse}\", \"#{approach_eta}\", " <<
                       "\"#{landing_queue.map(&:to_s).reverse}\", \"#{landing_queue_eta}\", " <<
                       "\"#{circling_queue.map(&:to_s).reverse}\", \"#{circling_eta}\", " <<
                       "\"#{landing_zone.map(&:to_s).reverse}\", \"#{landing_zone_eta}\", " <<
                       "\"#{done_queue.map(&:to_s).reverse}\", " <<
                       "\"#{n_a}\", \"#{n_lq}\", \"#{n_c}\", " <<
                       "\"#{n_lz}\", \"#{n_tp}\", " <<
                       "\"#{n_d}\"" <<
                       "\n"
  end

  # Adds any new arrivals at the current time to the landing queue
  def process_arrivals
    # Move any new arrivals from the future arrivals list to end of the landing queue
    while future_arrivals.length > 0 && future_arrivals.first.arrival_time == sim_time
      future_arrivals.first.start_approach!(sim_time)
      approaching_queue << future_arrivals.slice!(0)
      @n_a += 1
      print_update
    end
  end

  # Updates the landing queue state
  def process_approaching
    # Transition any aircraft that are ready to do so
    while approaching_queue.length > 0 && approaching_queue.first.is_at_queue?(sim_time)
      approaching_queue.first.start_queuing!(landing_queue.last, sim_time)
      landing_queue << approaching_queue.slice!(0)
      @n_lq += 1
      print_update
    end
  end

  # Updates the landing queue state
  def process_circling
    # Transition any aircraft that are ready to do so
    while circling_queue.length > 0 && circling_queue.first.is_at_queue?(sim_time)
      circling_queue.first.start_queuing!(landing_queue.last, sim_time)
      landing_queue << circling_queue.slice!(0)
      print_update
    end
  end

  # Updates the landing queue state
  def process_queuing
    # Transition any aircraft that are ready to do so
    while landing_queue.length > 0 && landing_zone.length == 0 && landing_queue.first.may_start_landing?(sim_time)
      landing_queue.first.start_landing!(sim_time)
      landing_zone << landing_queue.slice!(0)
      @n_lz += 1
      @n_tp += 1
      print_update
    end

    # Any other aircraft that are ready to land must circle if the landing zone is occupied
    while landing_queue.length > 0 && landing_zone.length == 1 && landing_queue.first.may_start_circling?(sim_time)
      landing_queue.first.start_circling!(sim_time)
      circling_queue << landing_queue.slice!(0)
      @n_c += 1
      @n_tp += 1
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
      print_update
    end
  end

  def all_aircraft_processed?
    done_queue.length == @arrival_count
  end

  def time_jump
    next_up = []
    next_up << @approaching_queue.first unless @approaching_queue.length == 0
    next_up << @circling_queue.first unless @circling_queue.length == 0
    next_up << @landing_queue.first unless @landing_queue.length == 0
    next_up << @landing_zone.first unless @landing_zone.length == 0
    next_up << @future_arrivals.first unless @future_arrivals.length == 0

    [sim_time + 1, next_up.collect{|a| a.transition_counter }.reject{|a| a.nil?}].flatten.min
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

end
