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
    event :approach do
      transitions from: [:contacted, :approaching], to: :approaching, unless: :is_at_queue?
      after do
        @approaching_time -= 1 unless @approaching_time < 1
      end
    end

    event :start_queuing, after: :queue_up do
      transitions from: [:approaching, :circling], to: :queuing, if: :is_at_queue?
    end

    event :queue do
      transitions from: :queuing, to: :queuing, unless: :is_at_threshold_point?
      after do
        @queuing_time -= 1 unless @queuing_time < 1
      end
    end

    event :start_circling do
      transitions from: :queuing, to: :circling, if: :is_at_threshold_point?
      after do
        @circling_time = positive_normal_random_number(750, 150)
      end
    end

    event :circle do
      transitions from: :circling, to: :circling, unless: :is_done_circling?
      after do
        @circling_time -= 1 unless @circling_time < 1
      end
    end

    event :start_landing do
      transitions from: :queuing, to: :landing, if: :is_at_threshold_point?
      after do
        @landing_time = positive_normal_random_number(750, 150)
      end
    end

    event :land do
      transitions from: :landing, to: :landing, unless: :is_done_landing?
      after do
        @landing_time -= 1 unless @landing_time < 1
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
    @queuing_time = 40
    @circling_time = 0
    @landing_time = 0

    generate_arrival_time
    generate_approaching_time
  end

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

  def airlines
    ['SATA', 'TAP', 'United', 'American', 'Delta']
  end

  def random_flight_number
    "#{airlines.sample} #{(800..4000).to_a.sample}"
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
  def queue_up(lead)
    if lead.nil?
      @queuing_time = 40
    else
      @queuing_time = separation_from(lead)
    end
  end

  # Given that the aircraft is approaching,
  # determines if it has reached the landing queue.
  # @return [TrueFalse] true if the aircraft is at the queue
  def is_at_queue?
    @approaching_time == 0
  end

  # Given that the aircraft is circling,
  # determines if it has reached the landing queue.
  # @return [TrueFalse] true if the aircraft is at the queue
  def is_done_circling?
    @circling_time == 0
  end

  # Given that the aircraft is queuing,
  # determines if it has reached the threshold point.
  # @return [TrueFalse] true if the aircraft is at the threshold point
  def is_at_threshold_point?
    @queuing_time == 0
  end

  # Given that the aircraft is landing,
  # determines if it is done landing.
  # @return [TrueFalse] true if the aircraft is done landing
  def is_done_landing?
    @landing_time == 0
  end

  # Returns an appropriately generated separation time
  # given the aircraft in front of this aircraft.
  def separation_from(lead)
    positive_normal_random_number(Aircraft::separation_mean[lead.type][self.type],
                                  Aircraft::separation_sd[lead.type][self.type])
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