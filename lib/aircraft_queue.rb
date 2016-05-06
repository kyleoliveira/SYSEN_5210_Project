require "#{File.expand_path(File.dirname(__FILE__))}/aircraft.rb"

class AircraftQueue < Array

  # Overloaded insertion operator. This is the only reason we're using a special class instead of
  # a simple Array, and it ensures that only Aircraft are put in this type of Array.
  # @param [Aircraft] aircraft The aircraft to add
  # @return [AircraftQueue] This AircraftQueue, with the new aircraft added
  # @raise [ArgumentError] If the object to be inserted is not an Aircraft
  def <<(aircraft)
    raise ArgumentError, 'This queue only works with aircraft!' unless aircraft.is_a?(Aircraft)
    super
  end

end