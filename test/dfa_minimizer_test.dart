import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_state/core/engine/automata_simulator.dart';
import 'package:infinite_state/core/regex/dfa_minimizer.dart';
import 'package:infinite_state/core/regex/regex_parser.dart';
import 'package:infinite_state/core/regex/regex_service.dart';
import 'package:infinite_state/core/regex/thompson_construction.dart';

void main() {
  group('DfaMinimizer', () {
    test('minimizes (a|b)*abb to 4-state clean DFA with 0 epsilons', () {
      final ast = RegexParser.parse('(a|b)*abb');
      final rawNfa = ThompsonConstruction.build(ast, applyLayout: false);

      // Raw Thompson produces bloated NFA
      expect(rawNfa.states.length, greaterThanOrEqualTo(10));
      expect(rawNfa.hasEpsilonTransitions, isTrue);

      final minDfa = DfaMinimizer.minimize(rawNfa, applyLayout: false);

      // Minimal DFA must have exactly 4 states
      expect(minDfa.states.length, equals(4));
      expect(minDfa.isDfa, isTrue);
      expect(minDfa.hasEpsilonTransitions, isFalse);

      // Verify acceptance behavior with AutomataSimulator
      bool accepts(String input) =>
          AutomataSimulator.run(automaton: minDfa, inputTape: input).isStringAccepted;

      expect(accepts('abb'), isTrue);
      expect(accepts('aabb'), isTrue);
      expect(accepts('babb'), isTrue);
      expect(accepts('ababb'), isTrue);
      expect(accepts('bbabb'), isTrue);

      expect(accepts(''), isFalse);
      expect(accepts('a'), isFalse);
      expect(accepts('ab'), isFalse);
      expect(accepts('b'), isFalse);
      expect(accepts('abba'), isFalse);
      expect(accepts('abbb'), isFalse);
    });

    test('minimizes second-from-end-is-1 "(0|1)*1(0|1)" to 4-state DFA', () {
      final ast = RegexParser.parse('(0|1)*1(0|1)');
      final rawNfa = ThompsonConstruction.build(ast, applyLayout: false);
      final minDfa = DfaMinimizer.minimize(rawNfa, applyLayout: false);

      expect(minDfa.states.length, equals(4));
      expect(minDfa.isDfa, isTrue);
      expect(minDfa.hasEpsilonTransitions, isFalse);

      bool accepts(String input) =>
          AutomataSimulator.run(automaton: minDfa, inputTape: input).isStringAccepted;

      expect(accepts('10'), isTrue);
      expect(accepts('11'), isTrue);
      expect(accepts('010'), isTrue);
      expect(accepts('0011'), isTrue);

      expect(accepts(''), isFalse);
      expect(accepts('0'), isFalse);
      expect(accepts('1'), isFalse);
      expect(accepts('00'), isFalse);
      expect(accepts('01'), isFalse);
      expect(accepts('100'), isFalse);
    });

    test('minimizes exactly two 1s "0*10*10*" to 3-state DFA', () {
      final ast = RegexParser.parse('0*10*10*');
      final rawNfa = ThompsonConstruction.build(ast, applyLayout: false);
      final minDfa = DfaMinimizer.minimize(rawNfa, applyLayout: false);

      expect(minDfa.states.length, equals(3));
      expect(minDfa.isDfa, isTrue);
      expect(minDfa.hasEpsilonTransitions, isFalse);

      bool accepts(String input) =>
          AutomataSimulator.run(automaton: minDfa, inputTape: input).isStringAccepted;

      expect(accepts('11'), isTrue);
      expect(accepts('01010'), isTrue);
      expect(accepts('001100'), isTrue);

      expect(accepts(''), isFalse);
      expect(accepts('1'), isFalse);
      expect(accepts('010'), isFalse);
      expect(accepts('111'), isFalse);
      expect(accepts('10101'), isFalse);
    });

    test('minimizes (a|b)* to 1-state DFA', () {
      final ast = RegexParser.parse('(a|b)*');
      final rawNfa = ThompsonConstruction.build(ast, applyLayout: false);
      final minDfa = DfaMinimizer.minimize(rawNfa, applyLayout: false);

      expect(minDfa.states.length, equals(1));
      expect(minDfa.isDfa, isTrue);
      expect(minDfa.hasEpsilonTransitions, isFalse);

      bool accepts(String input) =>
          AutomataSimulator.run(automaton: minDfa, inputTape: input).isStringAccepted;

      expect(accepts(''), isTrue);
      expect(accepts('a'), isTrue);
      expect(accepts('b'), isTrue);
      expect(accepts('abab'), isTrue);
    });

    test('handles epsilon and empty set base cases', () {
      final epsNfa = ThompsonConstruction.build(RegexParser.parse('ε'), applyLayout: false);
      final epsDfa = DfaMinimizer.minimize(epsNfa, applyLayout: false);
      expect(epsDfa.states.length, equals(1));
      expect(AutomataSimulator.run(automaton: epsDfa, inputTape: '').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: epsDfa, inputTape: 'a').isStringAccepted, isFalse);

      final emptyNfa = ThompsonConstruction.build(RegexParser.parse('∅'), applyLayout: false);
      final emptyDfa = DfaMinimizer.minimize(emptyNfa, applyLayout: false);
      expect(emptyDfa.states.length, equals(1));
      expect(AutomataSimulator.run(automaton: emptyDfa, inputTape: '').isStringAccepted, isFalse);
      expect(AutomataSimulator.run(automaton: emptyDfa, inputTape: 'a').isStringAccepted, isFalse);
    });

    test('RegexService honors RegexCompileMode.minimalDfa vs thompsonNfa', () {
      final dfa = RegexService.regexToAutomaton(
        '(a|b)*abb',
        mode: RegexCompileMode.minimalDfa,
        applyLayout: false,
      );
      final nfa = RegexService.regexToAutomaton(
        '(a|b)*abb',
        mode: RegexCompileMode.thompsonNfa,
        applyLayout: false,
      );

      expect(dfa.states.length, equals(4));
      expect(dfa.isDfa, isTrue);
      expect(dfa.hasEpsilonTransitions, isFalse);

      expect(nfa.states.length, greaterThanOrEqualTo(10));
      expect(nfa.hasEpsilonTransitions, isTrue);
    });
  });
}
