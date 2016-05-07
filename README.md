# How to Run

1) Install the necessary libraries/gems

If you have `bundler` installed:

```bash
bundle install
```

Otherwise:

```bash
gem install distribution aasm
```

2) Run the default script:

```bash
./run_simulation.rb
```

Or you can use irb:

```bash
irb
2.2.1 :001 > require './lib/simulation.rb'
 => true 
2.2.1 :002 > s = Simulation.new
...
2.2.1 :003 > s.run!
Simulation complete at 11596
```
And so on...
