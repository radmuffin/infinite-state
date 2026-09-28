import 'dart:ui';
import '../models/automaton.dart';
import 'dfa_minimizer.dart';
import 'regex_ast.dart';
import 'regex_parser.dart';
import 'state_elimination.dart';
import 'thompson_construction.dart';

/// Compilation strategy for converting regular expressions to finite automata.
enum RegexCompileMode {
  /// Minimal Deterministic Finite Automaton with 0 ε-transitions and minimal states.
  minimalDfa,

  /// Textbook Non-deterministic Finite Automaton with explicit ε-transitions.
  thompsonNfa,
}

/// High-level facade for regular expression analysis, compilation, and extraction.
class RegexService {
  /// Parses [pattern] into a simplified [RegexNode] AST.
  static RegexNode parse(String pattern) {
    return RegexParser.parse(pattern);
  }

  /// Converts a regular expression string into an equivalent [Automaton]
  /// using the selected [mode].
  static Automaton regexToAutomaton(
    String pattern, {
    RegexCompileMode mode = RegexCompileMode.minimalDfa,
    Size canvasSize = const Size(1200, 800),
    bool applyLayout = true,
  }) {
    final ast = parse(pattern);
    final rawNfa = ThompsonConstruction.build(
      ast,
      canvasSize: canvasSize,
      applyLayout: mode == RegexCompileMode.thompsonNfa && applyLayout,
    );

    if (mode == RegexCompileMode.thompsonNfa) {
      return rawNfa;
    }

    return DfaMinimizer.minimize(
      rawNfa,
      canvasSize: canvasSize,
      applyLayout: applyLayout,
    );
  }

  /// Extracts the equivalent regular expression string from an [Automaton].
  static String automatonToRegex(Automaton automaton) {
    final ast = StateElimination.toRegex(automaton);
    return ast.toRegexString();
  }

  /// Extracts the equivalent [RegexNode] AST from an [Automaton].
  static RegexNode automatonToAst(Automaton automaton) {
    return StateElimination.toRegex(automaton);
  }
}
