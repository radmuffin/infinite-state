# Infinite State

A high-performance visual state machine visualizer and simulator built with **Flutter & Dart**.

Infinite State provides an interactive node canvas for creating, manipulating, and simulating formal finite-state machines (DFAs, NFAs, and $\epsilon$-NFAs). It features real-time time-travel debugging, physical graph auto-layout algorithms, live transition tables, and a batch verification test runner.

---

## Features

### 1. Pure Dart Formal Automata Engine
* **DFA & NFA Simulation**: Simulates deterministic finite automata as well as nondeterministic automata with branching execution.
* **$\epsilon$-Transitions**: Full support for spontaneous transitions and recursive $\epsilon$-closure computation ($\epsilon\text{-closure}(S)$).
* **Formal Verification**: Automatic classification (DFA vs. NFA vs. $\epsilon$-NFA) and alphabet extraction ($\Sigma$).

### 2. Physical & Hierarchical Auto-Layout
* **Force-Directed Layout (Spring-Embedder / Fruchterman-Reingold)**: Simulates physical electrical repulsion ($k^2/d$) and spring attraction ($d^2/k$) with simulated annealing cooling to automatically untangle complex cyclic graphs.
* **Hierarchical Layered Layout (Sugiyama Framework)**: Ranks states into topological layers starting from the initial state $q_0$ to accepting states $F$, creating clean left-to-right textbook flow diagrams.

### 3. Interactive Visual Canvas
* **Infinite Pan & Zoom**: Smooth navigation with `InteractiveViewer` and snap-grid.
* **Smart Bézier Geometry**:
  * Reciprocal transitions ($A \to B$ and $B \to A$) automatically bow outward in opposite directions with quadratic Bézier curves to eliminate visual overlap.
  * Self-transitions render as smooth teardrop cubic curves.
  * Arrowheads align tangentially with circle perimeters.
* **Visual Execution Feedback**:
  * Active states pulse with glowing emerald/cyan auras.
  * Traversed transitions highlight with animated cyan glows.
  * Stuck/rejection paths illuminate in crimson.
  * Double concentric rings for accepting states; labeled start arrow for initial states.

### 4. Simulation & Time-Travel Debugger
* **Tape Strip**: Character-by-character tape strip tracking the read-head position.
* **Time-Travel Stepping**: Step forward, step backward, jump, scrub timeline slider, and auto-playback timer.
* **Acceptance Badges**: Real-time evaluation of string acceptance vs. rejection/stuck states.

### 5. Transition Matrix & Inspector
* **Live Attribute Inspector**: Rename states, toggle initial/accept states, edit transition symbols.
* **$\delta$-Matrix Table**: Live-generated formal transition table mapping all states $Q$ across alphabet $\Sigma \cup \{\epsilon\}$.

### 6. Batch Test Suite
* Enter a suite of test strings with expected outcomes (`Accept` / `Reject`) and verify pass rates in one click.

---

## Architecture

Infinite State is architected in distinct layers to scale from formal computer science automata to hierarchical software statecharts:

```
lib/
├── core/
│   ├── models/            # StateNode, Transition, Automaton (5-tuple formalization)
│   ├── engine/            # AutomataSimulator, SimulationStep (pure Dart, immutable trace)
│   ├── layout/            # ForceDirectedLayout, SugiyamaLayout, LayoutAlgorithm interface
│   └── presets/           # Textbook automata examples (Mod-3 binary, Substrings, ε-NFA)
├── state/
│   └── studio_controller.dart # Central reactive state manager & undo/redo stack
└── ui/
    ├── canvas/            # AutomataCanvas, CanvasPainter, TransitionGeometry
    ├── panels/            # Toolbar, InspectorPanel, SimulationBar, BatchTestDialog
    └── studio_page.dart   # Main application workspace
```

---

## Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.47+ recommended)
* Dart 3.13+

#### Linux Desktop Dependencies (Ubuntu/Debian)
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

#### Linux Desktop Dependencies (Arch / EndeavourOS)
```bash
sudo pacman -S clang cmake ninja pkg-config gtk3
```

### Running the App

```bash
# Run natively on Linux desktop
flutter run -d linux

# Run in Chrome web browser
flutter run -d chrome
```

### Running Tests

```bash
flutter test
```

---

## Roadmap

- [x] **Phase 1: Formal CS Automata**
  - DFA, NFA, $\epsilon$-NFA simulation
  - Force-Directed & Sugiyama auto-layout algorithms
  - Character-by-character tape scrubber
  - Live transition matrix ($\delta$-table) & batch test suite
- [ ] **Phase 2: Extended Software FSMs**
  - Typed blackboard context/variables
  - Transition guards (`[x > 0]`)
  - Entry/exit actions and transition effects
  - Code generation to idiomatic Dart 3 sealed classes
- [ ] **Phase 3: Hierarchical Statecharts (Harel / XState)**
  - Compound / nested states
  - Parallel / orthogonal regions
  - History states ($H, H^*$)
  - Timers and event delays
