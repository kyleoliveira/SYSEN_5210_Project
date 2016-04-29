require 'distribution'
require 'aasm'

# An aircraft for use in the simulation
class Aircraft

  attr_accessor :arrival_time,  # The time at which the aircraft makes initial contact, in seconds from simulation start
                :type,          # The aircraft type, one of: :small, :large, :heavy
                :approaching_time, # Time remaining until the aircraft reaches the landing queue
                :queuing_time,  # Time remaining until the aircraft reaches the threshold point
                :circling_time, # Time remaining until the aircraft has circled around
                :landing_time,  # Time remaining until the aircraft has cleared the landing zone
                :flight_number  # Silly identifier

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
    event :start_approach do
      transitions from: :contacted, to: :approaching, unless: :is_done_approaching?
      after do |current_time|
        @approaching_time += current_time
      end
    end

    event :start_queuing, after: :queue_up do
      transitions from: [:approaching, :circling], to: :queuing
    end

    event :start_circling do
      transitions from: :queuing, to: :circling, if: :is_at_threshold_point?
      after do |current_time|
        @circling_time = current_time + positive_normal_random_number(750, 150)
      end
    end

    event :start_landing do
      transitions from: :queuing, to: :landing, if: :is_at_threshold_point?
      after do |current_time|
        @queuing_time = 0
        @landing_time = current_time + positive_normal_random_number(750, 150)
      end
    end

    event :finish do
      transitions from: :landing, to: :done, if: :is_done_landing?
    end

  end

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

    @flight_number = random_flight_number

    @arrival_time = 0
    @approaching_time = 0
    @queuing_time = 0
    @circling_time = 0
    @landing_time = 0

    generate_arrival_time
    generate_approaching_time
  end

  # Generates a normally distributed random variable that is positive and an integer (since all calculations are in seconds)
  # @param [Float] mu The mean
  # @param [Float] sigma The standard deviation
  # @return [Integer] A normally distributed random variable that is positive and an integer
  def positive_normal_random_number(mu, sigma)
    result = Distribution::Normal.rng(mu, sigma).call.ceil.to_i
    until result >= 0
      result = Distribution::Normal.rng(mu, sigma).call.ceil.to_i
    end
    result
  end

  # Generates a random arrival time based on N(180, 60)
  def generate_arrival_time
    @arrival_time = positive_normal_random_number(180, 60)
  end

  # Generates a random approach time based on N(180, 60)
  def generate_approaching_time
    @approaching_time = positive_normal_random_number(600, 150)
  end

  # @return A list of airlines that our aircraft may fly for
  def airlines
    %w(SATA TAP United American Delta)
  end

  # Generates a pseudo random combination of an airline and a 3-4 digit number
  # @return A flight number
  def random_flight_number
    "#{airlines.sample} #{(800..4000).to_a.sample}"
  end

  # Convenience method for getting the current counter until the next transition
  # @return [Integer] The counter for the current transition
  def transition_counter
    case
      when approaching?
        approaching_time
      when queuing?
        queuing_time
      when circling?
        circling_time
      when landing?
        landing_time
      else
        nil
    end
  end

  #
  # Methods that will be triggered on state machine transitions
  #

  # Starts the aircraft queuing.
  # If the aircraft arriving at the landing queue finds the queue empty,
  # then it takes about 40 seconds to proceed to the threshold point.
  # Otherwise, the aircraft may potentially spend more time in the landing queue.
  # This additional time is based on the type of the aircraft and the aircraft preceding it and is
  # calculated based on the mean and standard deviation times provided.
  def queue_up(lead, current_time)
    if lead.nil?
      @queuing_time = current_time + 40
    else
      @queuing_time = current_time + separation_from(lead)
    end
  end

  # Given that the aircraft is approaching,
  # determines if it has reached the landing queue.
  # @return [TrueFalse] true if the aircraft is at the queue
  def is_done_approaching?(current_time)
    @approaching_time == current_time
  end

  # Given that the aircraft is circling,
  # determines if it has reached the landing queue.
  # @return [TrueFalse] true if the aircraft is at the queue
  def is_done_circling?(current_time)
    @circling_time == current_time
  end

  # Given that the aircraft is queuing,
  # determines if it has reached the threshold point.
  # @return [TrueFalse] true if the aircraft is at the threshold point
  def is_at_queue?(current_time)
    is_done_approaching?(current_time) || is_done_circling?(current_time)
  end

  # Given that the aircraft is queuing,
  # determines if it has reached the threshold point.
  # @return [TrueFalse] true if the aircraft is at the threshold point
  def is_at_threshold_point?(current_time)
    @queuing_time == current_time
  end

  # Given that the aircraft is landing,
  # determines if it is done landing.
  # @return [TrueFalse] true if the aircraft is done landing
  def is_done_landing?(current_time)
    @landing_time == current_time
  end

  # Returns an appropriately generated separation time
  # given the aircraft in front of this aircraft.
  def separation_from(lead)
    positive_normal_random_number(Aircraft::separation_mean[lead.type][self.type],
                                  Aircraft::separation_sd[lead.type][self.type])
  end

  # Converts the aircraft to a string for printing
  # @return The string
  def to_s
    "#{@flight_number} (#{type})#{@queuing_time > 0 ? ", ETA #{@queuing_time}" : ''}"
  end

  class << self

    attr_writer :separation_mean, # The mean of separation given lead (column) and in-trail (row) type
                :separation_sd    # The standard deviation of separation given lead (column) and in-trail (row) type

    # The table of means to use for calculating separation distances
    # @return The table of means
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

    # The table of standard deviations to use for calculating separation distances
    # @return The table of standard deviations
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

  end

end