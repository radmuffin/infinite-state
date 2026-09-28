import 'dart:ui';
import '../models/automaton.dart';
import 'regex_ast.dart';
import 'regex_parser.dart';
import 'state_elimination.dart';
import 'thompson_construction.dart';

/// High-level facade for regular expression analysis, compilation, and extraction.
class RegexService {
  /// Parses [pattern] into a simplified [RegexNode] AST.
  static RegexNode parse(String pattern) {
    return RegexParser.parse(pattern);
  }

  /// Converts a regular expression string into an equivalent [Automaton] (ε-NFA).
  static Automaton regexToAutomaton(
    String pattern, {
    Size canvasSize = const Size(1200, 800),
    bool applyLayout = true,
  }) {
    final ast = parse(pattern);
    return ThompsonConstruction.build(
      ast,
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
