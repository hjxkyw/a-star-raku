 # An implementation of the A* algorithm using the Raku language

> A Raku-based text visualization of the A* search algorithm.

## 🚀 Features

* Weighted A* Implementation: Full implementation using f = g + h cost logic.
* Dual Frontier visualization: Distinguishes between standard Frontier nodes (F) and high-cost Mud nodes (M).
* Interactive Mode: Step through the search logic one decision at a time.
* Auto-Play Mode: Watch the search unfold automatically with configurable speed.
* Detailed Logging: Output the grid state, current costs, and heap status to the terminal or a file.

## 📦 Installation

This project requires Raku.

1. Install Raku: https://raku.org/downloads/
2. Clone the repo:
   git clone https://github.com/YOUR_USERNAME/a-star-raku.git
   cd a-star-raku
3. Make executable:
   chmod +x a-star.raku

## 🎮 Usage

# 1. Interactive Mode (Step-by-Step)
The default mode. The program pauses after every step, allowing you to inspect the grid and the priority queue. Press ENTER to advance.

./a-star.raku

# 2. Auto-Play Mode
Runs the visualization automatically. You can specify the delay in seconds (default is 1.0s).

# Run with default 1 second delay
./a-star.raku -

# Run with custom 0.2 second delay (Fast mode)
./a-star.raku -0.2

# 3. Analysis Mode (File Log)
Suppress visual output and dump the complete expansion log to a file. Useful for debugging or performance analysis.

./a-star.raku log.txt

## 🗺️ The Grid Legend

Symbol  Meaning         Context
------  -------         -------
●       Agent           The node currently being expanded (The "Head").
★       Goal            The target destination.
○       Start           The starting point.
F       Frontier        A candidate node on Grass (Low cost).
M       Mud Frontier    A candidate node in Mud (High cost).
-       Explored        Nodes in the "Closed Set" (already visited).
~       Mud             Unexplored high-cost terrain.
.       Grass           Unexplored low-cost terrain.

## 🧠 The Logic: Why does it "Teleport"?

When you run the visualization, you will see the Agent (●) jump from (Col 2, Row 2) to (Col 8, Row 1) instantly. This is not a bug.

1. A* maintains a Min-Cost Heap of all known edge nodes (the Frontier).
2. Every step, it pops the node with the lowest Total Estimated Cost (f).
3. If the current path enters Mud, the g cost (effort so far) spikes by +10.
4. Suddenly, an old node left behind 5 turns ago has a lower f cost than the node in the mud.
5. The algorithm stops processing the mud path and "teleports" back to that old node to try a different route.

## 🛠 Technical Implementation

* Language: Raku (Perl 6)
* Architecture:
  * Role SearchProblem: Decouples the A* engine from the specific grid logic.
  * Class MinCostHeap: Custom binary heap implementation for the priority queue.
  * Class TerrainMap: Handles grid generation, mud randomization, and ASCII rendering.
* Heuristic: Manhattan Distance.

## 📄 License

Whatever license by the Raku language.

## WARNING FOR THE PURE OF HEART: AI GENERATED

All the code was written with AI assistance. Not "vibe code" though, because I do understand both the A* algorithm and the Raku programming language. (To be honest, after a certain point I stopped checking the code, and just ran tests with the program).
