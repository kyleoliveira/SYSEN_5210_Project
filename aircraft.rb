require 'distribution'

# An aircraft for use in the simulation
class Aircraft

  attr_accessor :arrival_time,  # The time at which the aircraft makes initial contact, in seconds from simulation start
                :type,          # The aircraft type, one of: :small, :large, :heavy
                :approaching_time, # Time remaining until the aircraft reaches the landing queue
                :queuing_time,  # Time remaining until the aircraft reaches the threshold point
                :circling_time, # Time remaining until the aircraft has circled around
                :landing_time,  # Time remaining until the aircraft has cleared the landing zone
                :status         # The aircraft's current state, one of:
                                #   :approaching, :queuing, :circling, :landing

  # Initializes the Aircraft's state
  def initialize

    # Type is randomly selected given the approximate distribution of types:
    type_random_sample = rand
    if type_random_sample > 0.67
      @type = :heavy
    elsif type_random_sample <= 0.67 && type_random_sample > 0.21
      @type = :large
    else
      @type = :small
    end

    generate_arrival_time
    start_approaching
    @queuing_time = 40
    @circling_time = 0
    @landing_time = 0

  end

  # Generates a random arrival time based on N(180, 60)
  def generate_arrival_time
    @arrival_time = Distribution::Normal.rng(180, 60).call
    until @arrival_time >= 0
      @arrival_time = Distribution::Normal.rng(180, 60).call
    end
  end

  #
  # Methods to handle circling in the landing queue:
  #

  # Advance the amount of time the aircraft has been circling, if necessary
  def circle
    start_queuing if @circling_time == 1
    @circling_time -= 1 unless @circling_time < 1
  end

  # Starts the aircraft circling
  def start_circling
    @circling_time = Distribution::Normal.rng(750, 150).call
    until @circling_time >= 0
      @circling_time = Distribution::Normal.rng(750, 150).call
    end

    @status = :circling
  end

  def is_circling?
    @status == :circling
  end

  #
  # Methods to handle approaching the landing queue:
  #

  # Advance the amount of time the aircraft has been approaching, if necessary
  def approach
    start_queuing if @approaching_time == 1
    @approaching_time -= 1 unless @approaching_time < 1
  end

  # Starts the aircraft circling
  def start_approaching
    @approaching_time = Distribution::Normal.rng(600, 150).call
    until @approaching_time >= 0
      @approaching_time = Distribution::Normal.rng(600, 150).call
    end

    @status = :approaching
  end

  def is_approaching?
    @status == :approaching
  end

  #
  # Methods for handling landing
  #

  # Advance the amount of time the aircraft has been approaching, if necessary
  def queue
    @queuing_time -= 1 unless @queuing_time < 1
  end

  # Starts the aircraft queuing
  def start_queuing
    @queuing_time = 40
    @status = :queuing
  end

  def is_queuing?
    @status == :queuing
  end

  def is_at_threshold_point?
    @status == :queuing && @queuing_time == 0
  end

  # Advance the amount of time the aircraft has been landing, if necessary
  def land
    @landing_time -= 1 unless @landing_time < 1
  end

  # Starts the aircraft landing
  def start_landing
    @landing_time = Distribution::Normal.rng(750, 150).call
    until @landing_time >= 0
      @landing_time = Distribution::Normal.rng(750, 150).call
    end

    @status = :landing
  end

  def is_landing?
    @status == :landing
  end

  #
  # Methods for handling separation
  #

  # Returns an appropriately generated separation time
  # given the aircraft in front of this aircraft.
  def separation_from(lead)
    separation = Distribution::Normal.rng(Aircraft::separation_mean[lead.type][self.type],
                                          Aircraft::separation_sd[lead.type][self.type])
                                     .call
    until separation >= 0
      separation = Distribution::Normal.rng(Aircraft::separation_mean[lead.type][self.type],
                                            Aircraft::separation_sd[lead.type][self.type])
                       .call
    end

    separation
  end


  class << self

    # The mean of separation given lead (column) and in-trail (row) type
    def separation_mean
      {
          heavy: {
              heavy: 64,
              large: 108,
              small: 130
          },
          large: {
              heavy: 64,
              large: 86,
              small: 130
          },
          small: {
              heavy: 64,
              large: 64,
              small: 64
          }
      }
    end

    # The standard deviation of separation given lead (column) and in-trail (row) type
    def separation_sd
      {
          heavy: {
              heavy: 30,
              large: 40,
              small: 50
          },
          large: {
              heavy: 30,
              large: 40,
              small: 50
          },
          small: {
              heavy: 30,
              large: 30,
              small: 30
          }
      }
    end

  end

end