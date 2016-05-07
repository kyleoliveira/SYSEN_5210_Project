require 'distribution'
require 'aasm'

# An aircraft for use in the simulation
class Aircraft

  attr_accessor :type,               # The aircraft type, one of: :small, :large, :heavy
                :next_transition_at, # The time at which the aircraft will attempt to transition to its next state
                :flight_number       # Silly identifier

  include AASM

  # Define a state machine to represent how the aircraft state changes throughout the simulation
  aasm do

    # Aircraft states
    state :contacted, initial: true
    state :approaching
    state :queuing
    state :circling
    state :landing
    state :done

    # Events that transition an aircraft between states
    event :approach do
      transitions from: :contacted, to: :approaching
      after do |current_time|
        @next_transition_at = current_time + positive_normal_random_number(600, 150)
      end
    end

    event :queue, after: :queue_up do
      transitions from: :approaching, to: :queuing
    end

    event :requeue, after: :queue_up do
      transitions from: :circling, to: :queuing
    end

    event :circle do
      transitions from: :queuing, to: :circling, if: :at_threshold_point?
      after do |current_time|
        @next_transition_at = current_time + positive_normal_random_number(750, 150)
      end
    end

    event :land do
      transitions from: :queuing, to: :landing, if: :at_threshold_point?
      after do |current_time|
        @next_transition_at = current_time + positive_normal_random_number(120, 30)
      end
    end

    event :finish do
      transitions from: :landing, to: :done, if: :done_landing?
    end

  end

  # Initializes the Aircraft's state
  def initialize
    @type = Aircraft::random_type
    @flight_number = Aircraft::random_flight_number
    @next_transition_at = positive_normal_random_number(180, 60)
  end

  # Compares an aircraft against another aircraft for sorting purposes.
  # This is only useful if the aircraft are in the same queue.
  # @param [Aircraft] other_aircraft The aircraft to compare against
  # @return [Integer] -1,0,1 depending on where the aircraft should be sorted
  def <=>(other_aircraft)
    self.next_transition_at <=> other_aircraft.next_transition_at
  end

  # Converts the aircraft to a string for printing
  # @return [String] The info string
  def to_s
    "#{@flight_number} (#{type}), ETA #{@next_transition_at}"
  end

  # Generates a normally distributed random variable that is positive and an integer (since all calculations are in seconds)
  # @param [Float] mu The mean
  # @param [Float] sigma The standard deviation
  # @return [Integer] A normally distributed random variable that is positive and an integer
  def positive_normal_random_number(mu, sigma)
    result = Distribution::Normal.rng(mu, sigma).call.ceil.to_i
    while result < 0
      result = Distribution::Normal.rng(mu, sigma).call.ceil.to_i
    end

    # The while-loop should prevent this from ever happening, buuuuut...
    raise RangeError, "#{result} is a negative normal random number for some reason! Woe is me!" if result < 0

    result
  end

  #
  # Methods that will be triggered on state machine transitions:
  #

  # Starts the aircraft queuing.
  # If the aircraft arriving at the landing queue finds the queue empty,
  # then it takes about 40 seconds to proceed to the threshold point.
  # Otherwise, the aircraft may potentially spend more time in the landing queue.
  # This additional time is based on the type of the aircraft and the aircraft preceding it and is
  # calculated based on the mean and standard deviation times provided.
  # @param [Aircraft] lead The aircraft in front of the aircraft that is queuing up
  # @param [Integer] current_time The current simulation time
  def queue_up(lead, current_time)
    if lead.nil?
      @next_transition_at = current_time + 40
    else
      @next_transition_at = lead.next_transition_at + separation_from(lead)
    end
  end

  # Given that the aircraft is approaching,
  # determines if it has reached the landing queue.
  # @return [TrueFalse] true if the aircraft is at the queue
  def done_approaching?(current_time)
    approaching? && @next_transition_at == current_time
  end

  # Given that the aircraft is circling,
  # determines if it has reached the landing queue.
  # @return [TrueFalse] true if the aircraft is at the queue
  def done_circling?(current_time)
    circling? && @next_transition_at == current_time
  end

  # Given that the aircraft is queuing,
  # determines if it has reached the threshold point.
  # @return [TrueFalse] true if the aircraft is at the threshold point
  def at_threshold_point?(current_time)
    queuing? && @next_transition_at == current_time
  end

  # Given that the aircraft is landing,
  # determines if it is done landing.
  # @return [TrueFalse] true if the aircraft is done landing
  def done_landing?(current_time)
    landing? && @next_transition_at == current_time
  end

  # Returns an appropriately generated separation time
  # given the aircraft in front of this aircraft.
  def separation_from(lead)
    positive_normal_random_number(Aircraft::separation_mean[lead.type][self.type],
                                  Aircraft::separation_sd[lead.type][self.type])
  end

  # For non-Ruby people:
  # Everything in the following block is a class variable or method (essentially a singleton). Whenever you see something
  # like:
  #   Aircraft::some_method
  # it is calling some_method out of the block below.
  class << self

    attr_writer :separation_mean, # The mean of separation given lead (column) and in-trail (row) type
                :separation_sd    # The standard deviation of separation given lead (column) and in-trail (row) type

    # The table of means to use for calculating separation distances
    # @return [Hash] The table of means
    def separation_mean
      @separation_mean || {
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

    # Scales the means table by a given factor.
    # @param [Float] factor The factor to multiply each value in the table by
    def scale_separation_mean_by(factor)
      Aircraft::separation_mean = Aircraft::separation_mean.each do |_, means|
        means.each do |key, value|
          means[key] = value * factor
        end
      end
    end

    # The table of standard deviations to use for calculating separation distances
    # @return [Hash] The table of standard deviations
    def separation_sd
      @separation_sd || {
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

    # Scales the standard deviations table by a given factor.
    # @param [Float] factor The factor to multiply each value in the table by
    def scale_separation_sd_by(factor)
      Aircraft::separation_sd = Aircraft::separation_sd.each do |_, sds|
        sds.each do |key, value|
          sds[key] = value * factor
        end
      end
    end

    # A list of airlines that can be used for generating flight numbers
    # @return [String] A list of airlines that our aircraft may fly for
    def airlines
      %w(SATA TAP United American Delta NZ BA JetBlue)
    end

    # Generates a pseudo-random combination of an airline and a 3-4 digit number
    # @return [String] A flight number
    def random_flight_number
      "#{Aircraft::airlines.sample} #{(800..4000).to_a.sample}"
    end

    # Selects a random type based on the probability of a particular type arriving at the airport.
    # @return [Symbol] The type
    def random_type
      # Type is randomly selected given the approximate distribution of types:
      type_random_sample = rand
      if type_random_sample > 0.67
        :heavy
      elsif type_random_sample <= 0.67 && type_random_sample > 0.21
        :large
      else
        :small
      end
    end

  end

end