#!/usr/bin/raku
# --------------------------------------------------------------------------------
# a_star.raku
# --------------------------------------------------------------------------------

use v6;

# ==============================================================================
# PART 1: The Generic Search Framework
# ==============================================================================

# Role: SearchProblem
# This role defines the interface required for any spatial search problem.
# It allows the A* algorithm to remain decoupled from the specific grid logic.
role SearchProblem
{
  method initial-location() { ... }
  method is-goal($location) { ... }
  method successors($location) { ... }
  method heuristic($location) { ... }
  method is-mud($location) { ... }
}

# Class: Node
# A Node represents a specific "promise" in the search tree.
# It stores the cost to reach a location and a reference to the previous step.
class Node
{
  has $.location;    # The Location object representing a coordinate
  has Node $.parent; # The Node that led to this one (used for backtracking)
  has $.action;      # The descriptive action taken (e.g., "Down", "Right")

  # g-cost: The exact cost of the path from the starting point to this node.
  has Real $.g-cost is rw = 0;

  # h-cost: The heuristic estimate of the cost to get from here to the goal.
  has Real $.h-cost is rw = 0;

  # f-cost: The total estimated cost of the lowest-cost path through this node.
  # A* always chooses the node with the lowest f-cost to expand next.
  method f-cost
  {
    return $.g-cost + $.h-cost;
  }
}

# ==============================================================================
# PART 2: Implementation (Grid and Coordinates)
# ==============================================================================

# Class: Location
# Represents a physical 2D coordinate (x, y) on the map.
class Location
{
  has Int $.x;
  has Int $.y;

  # Returns a unique string key used for tracking explored locations in hashes.
  method key
  {
    return "$!x,$!y";
  }

  # For display
  method Str
  {
    return "(Col $!x, Row $!y)";
  }

  # Manhattan Distance: The sum of the absolute differences of their coordinates.
  # This is the standard "admissible" heuristic for grid movement without diagonals.
  method dist(Location $p)
  {
    return abs($!x - $p.x) + abs($!y - $p.y);
  }
}

# Equality operator override for Location objects to compare coordinates easily.
multi sub infix:<==>(Location $a, Location $b)
{
  return $a.x == $b.x && $a.y == $b.y;
}

# Class: TerrainMap
# Manages the grid environment, terrain costs, and the visual rendering logic.
class TerrainMap does SearchProblem
{
  constant COST_GRASS = 1;
  constant COST_MUD   = 10;

  has Int $.width;
  has Int $.height;
  has Location $.start;
  has Location $.goal;
  has Bool %!mud-tiles;

  # submethod: TWEAK
  # Automatically generates a random distribution of mud tiles during construction.
  submethod TWEAK
  {
    for 0 ..^ $!width -> $x
    {
      for 0 ..^ $!height -> $y
      {
        my $p = Location.new(x => $x, y => $y);
        next if $p == $!start || $p == $!goal;
        if rand < 0.3
        {
          %!mud-tiles{$p.key} = True;
        }
      }
    }
  }

  method initial-location() { return $.start; }
  method is-goal($loc) { return $loc == $.goal; }
  method heuristic($loc) { return $loc.dist($.goal); }
  method is-mud($loc) { return %!mud-tiles{$loc.key} // False; }

  # method: successors
  # Generates adjacent locations and assigns movement costs based on terrain.
  method successors($loc)
  {
    my @moves;
    my @directions = ( [0,1,"Down"], [0,-1,"Up"], [1,0,"Right"], [-1,0,"Left"] );
    for @directions -> $d
    {
      my $nx = $loc.x + $d[0];
      my $ny = $loc.y + $d[1];
      if $nx >= 0 && $nx < $!width && $ny >= 0 && $ny < $!height
      {
        my $p = Location.new(x => $nx, y => $ny);
        my $cost = %!mud-tiles{$p.key} ?? COST_MUD !! COST_GRASS;
        @moves.push: [$d[2], $p, $cost];
      }
    }

    return @moves;
  }

  # method: render
  # Draws the ASCII grid.
  # Symbols:
  #   ● = Agent
  #   ★ = Goal
  #   F = Frontier (Grass)
  #   M = Frontier (Mud)
  #   - = Explored
  #   ~ = Mud (Unexplored)
  method render(Location $agent-loc, @path-actions, @frontier-nodes, %closed-set, $handle)
  {
    my %path-keys;
    if @path-actions
    {
      my $curr = $.start;
      for @path-actions -> $act
      {
        given $act
        {
          when "Up"    { $curr = Location.new(x => $curr.x, y => $curr.y - 1); }
          when "Down"  { $curr = Location.new(x => $curr.x, y => $curr.y + 1); }
          when "Left"  { $curr = Location.new(x => $curr.x - 1, y => $curr.y); }
          when "Right" { $curr = Location.new(x => $curr.x + 1, y => $curr.y); }
        }
        # Select arrow based on terrain (Outline for Mud, Solid for Grass)
        my $m = %!mud-tiles{$curr.key} ??
        ( $act eq "Up" ?? " ⬆ " !! $act eq "Down" ?? " ⬇ " !! $act eq "Left" ?? " ⬅ " !! " ➡ " ) !!
        ( $act eq "Up" ?? " ↑ " !! $act eq "Down" ?? " ↓ " !! $act eq "Left" ?? " ← " !! " → " );
        %path-keys{$curr.key} = $m if $curr.key ne $agent-loc.key;
      }
    }

    my %frontier-keys;
    for @frontier-nodes -> $node
    {
      my $pk = $node.location.key;
      if $pk ne $agent-loc.key && !%path-keys{$pk}
      {
        %frontier-keys{$pk} = True;
      }
    }

    $handle.say: "\n" ~ ("=" x 30);
    $handle.say: "A* GRID STATE";
    $handle.say: "-" x 30;

    for 0 ..^ $!height -> $y
    {
      for 0 ..^ $!width -> $x
      {
        my $p = Location.new(x => $x, y => $y);
        my $k = $p.key;
        if $k eq $agent-loc.key { $handle.print: " ● "; }
        elsif $k eq $.goal.key { $handle.print: " ★ "; }
        elsif $k eq $.start.key { $handle.print: " ○ "; }
        elsif %path-keys{$k}:exists { $handle.print: %path-keys{$k}; }
        elsif %frontier-keys{$k}:exists
        {
          # M for Mud Frontier, F for Grass Frontier
          $handle.print: %!mud-tiles{$k} ?? " M " !! " F ";
        }
        elsif %closed-set{$k}:exists { $handle.print: " - "; }
        elsif %!mud-tiles{$k} { $handle.print: " ~ "; }
        else { $handle.print: " . "; }
      }
      $handle.say: "";
    }

    $handle.say: "-" x 30;
  }
} # end of class TerrainMap

# ==============================================================================
# PART 3: Data Structures (Priority Queue)
# ==============================================================================

# Class: MinCostHeap
# A binary heap that keeps the most promising node (lowest f-cost) at the root.
class MinCostHeap
{
  # array of items
  has @!items;

  # comparison function
  has &.compare is required;
  method push($item)
  {
    @!items.push($item);
    self!sift-up(@!items.end);
  }

  method pop()
  {
    return Nil if self.is-empty;
    my $r = @!items[0];
    my $l = @!items.pop;
    if !self.is-empty
    {
      @!items[0] = $l;
      self!sift-down(0);
    }
    return $r;
  }

  method is-empty { return +@!items == 0; }
  method to-list { return @!items; }

  # private method
  # Maintenance methods to restore heap property after push/pop
  method !sift-up($idx is copy)
  {
    while $idx > 0
    {
      my $p = ($idx - 1) div 2;
      if &!compare(@!items[$idx], @!items[$p]) < 0
      {
        (@!items[$idx], @!items[$p]) = (@!items[$p], @!items[$idx]);
        $idx = $p;
      }
      else { last; }
    }
  }

  # private method
  method !sift-down($idx is copy)
  {
    loop
    {
      my ($l, $r) = 2*$idx+1, 2*$idx+2;
      my $s = $idx;
      $s = $l if $l <= @!items.end && &!compare(@!items[$l], @!items[$s]) < 0;
      $s = $r if $r <= @!items.end && &!compare(@!items[$r], @!items[$s]) < 0;
      if $s != $idx
      {
        (@!items[$idx], @!items[$s]) = (@!items[$s], @!items[$idx]);
        $idx = $s;
      }
      else { last; }
    }
  }
}

# ==============================================================================
# PART 4: MAIN LOGIC
# ==============================================================================

# sub: reconstruct-path
# Follows the parent pointers from the goal node back to the start using references.
sub reconstruct-path(Node $end-node is copy)
{
  my @path;

  while $end-node.parent
  {
    @path.unshift: $end-node.action.Str;
    $end-node = $end-node.parent;
  }

  return @path;
}

# --------------------------------------------------------------------------------

# sub: run-experiment
# The engine that executes the search, manages the frontier, and reports stats.
# Parameters:
#   :$interactive - If true, outputs visual grid to handle.
#   :$auto-play   - If true, waits automatically instead of asking for keypress.
#   :$wait-time   - The time to sleep (seconds) in auto-play mode.
#   :$show-menu   - If true, prints the full list of frontier nodes.
sub run-experiment(TerrainMap $map, $out-handle, Bool :$interactive, Bool :$auto-play = False, Real :$wait-time = 1, Bool :$show-menu = True)
{
  # 1. Initialize start node and frontier
  my $root = Node.new(location => $map.initial-location, h-cost => $map.heuristic($map.initial-location));
  my $frontier = MinCostHeap.new(compare => { $^a.f-cost <=> $^b.f-cost });
  $frontier.push($root);
  # %best tracks the lowest cost found to reach any given coordinate.
  my %best = ($map.initial-location.key => 0);
  # %closed-set tracks nodes that have already been expanded.
  my %closed-set;

  my $step-count = 0;
  while !$frontier.is-empty
  {
    # 2. Pick the best node (lowest f-cost) from the open set
    my $curr = $frontier.pop;
    $step-count++;

    # 3. Mark as closed (Interior of the search area)
    %closed-set{$curr.location.key} = True;
    my $terrain = $map.is-mud($curr.location) ?? "(MUD)" !! "(GRASS)";
    my $act-text = $curr.action ?? "Moved " ~ $curr.action.Str !! "Started";
    $out-handle.say: "\nSTEP $step-count:";
    $out-handle.say: "  CHOSEN: $act-text to {$curr.location} $terrain";
    $out-handle.say: "  COST DETAIL: f={ $curr.f-cost } (g={ $curr.g-cost } + h={ $curr.h-cost })";
    # 4. Check for success
    if $map.is-goal($curr.location)
    {
      my @final-path = reconstruct-path($curr);
      $map.render($curr.location, @final-path, $frontier.to-list, %closed-set, $out-handle);

      # Diagnostics
      my $path-length = @final-path.elems;
      my $total-explored = %closed-set.elems;
      my $efficiency = ($path-length / $total-explored) * 100;

      $out-handle.say: "\nSUCCESS! Goal reached at {$curr.location}.";
      $out-handle.say: "--------------------------------------------------";
      $out-handle.say: "EXPLORATION DIAGNOSTICS:";
      $out-handle.say: "  Path Length:       $path-length steps";
      $out-handle.say: "  Total Explored:    $total-explored points";
      $out-handle.say: "  Search Efficiency: " ~ $efficiency.fmt("%.2f") ~ "%";
      $out-handle.say: "--------------------------------------------------";
      return;
    }

    # 5. Expand neighbors (add to frontier)
    if !($curr.g-cost > (%best{$curr.location.key} // Inf))
    {
      for $map.successors($curr.location) -> @t
      {
        my ($new-g, $key) = $curr.g-cost + @t[2], @t[1].key;
        # Only add to frontier if this is a shorter path to this location than any previously found.
        if $key ∉ %best || $new-g < %best{$key}
        {
          %best{$key} = $new-g;
          $frontier.push(Node.new(
            location => @t[1],
            parent   => $curr,
            action   => @t[0],
            g-cost   => $new-g,
            h-cost   => $map.heuristic(@t[1])
          ));
        }
      }
    }

    # 6. Visualization for this step
    $map.render($curr.location, reconstruct-path($curr), $frontier.to-list, %closed-set, $out-handle);
    $out-handle.say: "CURRENT LOCATION: {$curr.location} $terrain";

    if $show-menu
    {
      my @f-list = $frontier.to-list.sort({ .f-cost });
      $out-handle.say: "  MENU FOR NEXT STEP (Current Frontier):";
      if @f-list
      {
        for @f-list -> $n
        {
          my $marker = ($n === @f-list[0]) ??
          " -> " !! "    ";
          $out-handle.say: "$marker {$n.location}: f={ $n.f-cost } (g={ $n.g-cost } + h={ $n.h-cost })";
        }
      }
      else
      {
        $out-handle.say: "    (Empty)";
      }
    }

    # 7. Pause for user interaction (if not logging to file)
    if $interactive
    {
      if $auto-play
      {
        sleep $wait-time;
      }
      else
      {
        print "\n[Press ENTER for next step...]";
        $*IN.get;
      }
    }
  }
} # end of sub run-experiment

# --------------------------------------------------------------------------------

# MAIN with slurpy params (*@pos, *%named) to handle flags like -2 correctly
sub MAIN(*@pos, *%named)
{
  # Determine the argument
  my $arg;

  if @pos.elems > 0
  {
    $arg = @pos[0];
  }
  elsif %named.elems > 0
  {
    # Check if we have a named argument that looks like a number (e.g. '2' => True for -2)
    # Get the first key from the hash
    my $key = %named.keys[0];

    # If the user typed -2, Raku provides { 2 => True }. We reconstruct "-2".
    # If the user typed -0.5, Raku provides { 0.5 => True }. We reconstruct "-0.5".
    # Note: This is a hack because Raku parses negative numbers as flags.
    $arg = "-$key";
  }

  # Setup the map (10x10 grid)
  my $map = TerrainMap.new(
    width  => 10,
    height => 10,
    start  => Location.new(x => 0, y => 0),
    goal   => Location.new(x => 9, y => 9)
  );

  # Mode Selection based on argument
  if !$arg
  {
    # Default: Interactive, Step-by-Step, Show Menu
    run-experiment($map, $*OUT, interactive => True, auto-play => False, show-menu => True);
  }
  elsif $arg eq '-'
  {
    # Dash: Interactive, Auto-play (default 1s), Hide Menu
    say "Auto-play mode (1.0s delay)...";
    run-experiment($map, $*OUT, interactive => True, auto-play => True, wait-time => 1, show-menu => False);
  }
  elsif $arg ~~ /^ \- (<[\d.]>+) $/
  {
    # Dash + Number (e.g., -0.5): Interactive, Auto-play (custom time), Hide Menu
    my $w = $0.Numeric;
    say "Auto-play mode ({$w}s delay)...";
    run-experiment($map, $*OUT, interactive => True, auto-play => True, wait-time => $w, show-menu => False);
  }
  else
  {
    # Filename: Log to file, No Wait, Show Menu (in log)
    my $fh = open $arg, :w;
    say "Logging expansion to $arg...";
    run-experiment($map, $fh, interactive => False, auto-play => False, show-menu => True);
    $fh.close;
    say "Done.";
  }
}

# --------------------------------------------------------------------------------
# the end
