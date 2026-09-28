import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_state/core/engine/automata_simulator.dart';
import 'package:infinite_state/core/models/automaton.dart';
import 'package:infinite_state/core/models/state_node.dart';
import 'package:infinite_state/core/models/transition.dart';
import 'package:infinite_state/core/presets/example_automata.dart';
import 'package:infinite_state/core/regex/regex_ast.dart';
import 'package:infinite_state/core/regex/regex_parser.dart';
import 'package:infinite_state/core/regex/regex_service.dart';
import 'package:infinite_state/state/studio_controller.dart';

void main() {
  group('Regex AST & Simplification Tests', () {
    test('RegexNode stringifies with minimal parentheses based on precedence', () {
      // a | bc
      final ast1 = RegexUnion([
        const RegexLiteral('a'),
        const RegexConcat([RegexLiteral('b'), RegexLiteral('c')]),
      ]);
      expect(ast1.toRegexString(), equals('a|bc'));

      // (a | b) c
      final ast2 = RegexConcat([
        const RegexUnion([RegexLiteral('a'), RegexLiteral('b')]),
        const RegexLiteral('c'),
      ]);
      expect(ast2.toRegexString(), equals('(a|b)c'));

      // (a | b)*
      final ast3 = RegexStar(
        const RegexUnion([RegexLiteral('a'), RegexLiteral('b')]),
      );
      expect(ast3.toRegexString(), equals('(a|b)*'));

      // a* b
      final ast4 = RegexConcat([
        const RegexStar(RegexLiteral('a')),
        const RegexLiteral('b'),
      ]);
      expect(ast4.toRegexString(), equals('a*b'));
    });

    test('Algebraic simplification collapses identities and redundant operators', () {
      // r · ε = r
      final c1 = RegexConcat([const RegexLiteral('a'), const RegexEpsilon()]);
      expect(c1.simplify().toRegexString(), equals('a'));

      // r · ∅ = ∅
      final c2 = RegexConcat([const RegexLiteral('a'), const RegexEmpty()]);
      expect(c2.simplify(), equals(const RegexEmpty()));

      // r | ∅ = r
      final u1 = RegexUnion([const RegexLiteral('a'), const RegexEmpty()]);
      expect(u1.simplify().toRegexString(), equals('a'));

      // r | r = r
      final u2 = RegexUnion([const RegexLiteral('a'), const RegexLiteral('a')]);
      expect(u2.simplify().toRegexString(), equals('a'));

      // (r*)* = r*
      final s1 = RegexStar(RegexStar(const RegexLiteral('a')));
      expect(s1.simplify().toRegexString(), equals('a*'));

      // ∅* = ε, ε* = ε
      expect(const RegexStar(RegexEmpty()).simplify(), equals(const RegexEpsilon()));
      expect(const RegexStar(RegexEpsilon()).simplify(), equals(const RegexEpsilon()));
    });
  });

  group('Regex Parser Tests', () {
    test('Parses literals, implicit concatenation, and unions', () {
      final ast = RegexParser.parse('a|b');
      expect(ast, isA<RegexUnion>());
      expect(ast.toRegexString(), equals('a|b'));

      final astConcat = RegexParser.parse('abc');
      expect(astConcat, isA<RegexConcat>());
      expect(astConcat.toRegexString(), equals('abc'));
    });

    test('Parses postfix operators: star, plus, question', () {
      expect(RegexParser.parse('a*').toRegexString(), equals('a*'));
      expect(RegexParser.parse('a+').toRegexString(), equals('a+'));
      expect(RegexParser.parse('a?').toRegexString(), equals('a?'));
    });

    test('Parses textbook expressions with grouping', () {
      final ast = RegexParser.parse('(a|b)*abb');
      expect(ast.toRegexString(), equals('(a|b)*abb'));

      final astBinary = RegexParser.parse('(0|1)*10*');
      expect(astBinary.toRegexString(), equals('(0|1)*10*'));
    });

    test('Parses epsilon and empty set aliases', () {
      expect(RegexParser.parse('ε').toRegexString(), equals('ε'));
      expect(RegexParser.parse(r'\e').toRegexString(), equals('ε'));
      expect(RegexParser.parse('eps').toRegexString(), equals('ε'));
      expect(RegexParser.parse('∅').toRegexString(), equals('∅'));
      expect(RegexParser.parse(r'\0').toRegexString(), equals('∅'));
      expect(RegexParser.parse('').toRegexString(), equals('ε'));
    });

    test('Throws informative RegexParseException on invalid syntax', () {
      expect(() => RegexParser.parse('(a|b'), throwsA(isA<RegexParseException>()));
      expect(() => RegexParser.parse('*a'), throwsA(isA<RegexParseException>()));
    });
  });

  group("Thompson's Construction (Regex -> NFA) Tests", () {
    test('Builds NFA for literal', () {
      final nfa = RegexService.regexToAutomaton('a', mode: RegexCompileMode.thompsonNfa);
      expect(nfa.states.length, equals(2));
      expect(nfa.transitions.length, equals(1));
      expect(nfa.initialState, isNotNull);
      expect(nfa.acceptStateIds.length, equals(1));

      expect(AutomataSimulator.run(automaton: nfa, inputTape: 'a').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: 'b').isStringAccepted, isFalse);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: '').isStringAccepted, isFalse);
    });

    test('Builds NFA for (a|b)*abb textbook pattern', () {
      final nfa = RegexService.regexToAutomaton('(a|b)*abb', mode: RegexCompileMode.thompsonNfa);
      expect(nfa.hasEpsilonTransitions, isTrue);

      // Matches
      expect(AutomataSimulator.run(automaton: nfa, inputTape: 'abb').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: 'aabb').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: 'babb').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: 'ababb').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: 'bbababb').isStringAccepted, isTrue);

      // Rejections
      expect(AutomataSimulator.run(automaton: nfa, inputTape: '').isStringAccepted, isFalse);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: 'ab').isStringAccepted, isFalse);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: 'abba').isStringAccepted, isFalse);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: 'bba').isStringAccepted, isFalse);
    });

    test('Builds NFA for positive closure (01|10)+', () {
      final nfa = RegexService.regexToAutomaton('(01|10)+', mode: RegexCompileMode.thompsonNfa);

      expect(AutomataSimulator.run(automaton: nfa, inputTape: '01').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: '10').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: '0110').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: '100101').isStringAccepted, isTrue);

      expect(AutomataSimulator.run(automaton: nfa, inputTape: '').isStringAccepted, isFalse);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: '0').isStringAccepted, isFalse);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: '1').isStringAccepted, isFalse);
      expect(AutomataSimulator.run(automaton: nfa, inputTape: '00').isStringAccepted, isFalse);
    });
  });

  group('State Elimination (Automaton -> Regex) Tests', () {
    test('Single state self loop produces Kleene star', () {
      final q0 = StateNode(
        id: 'q0',
        label: 'q0',
        position: Offset.zero,
        isInitial: true,
        isAccept: true,
      );
      final t = Transition(
        id: 't0',
        fromId: 'q0',
        toId: 'q0',
        symbols: {'0'},
      );
      final automaton = Automaton(
        states: {'q0': q0},
        transitions: [t],
      );

      final regex = RegexService.automatonToRegex(automaton);
      expect(regex, equals('0*'));
    });

    test('Two state sequence produces concatenation', () {
      final q0 = StateNode(id: 'q0', label: 'q0', position: Offset.zero, isInitial: true, isAccept: false);
      final q1 = StateNode(id: 'q1', label: 'q1', position: Offset.zero, isInitial: false, isAccept: true);
      final t = Transition(id: 't0', fromId: 'q0', toId: 'q1', symbols: {'a'});
      final automaton = Automaton(
        states: {'q0': q0, 'q1': q1},
        transitions: [t],
      );

      final regex = RegexService.automatonToRegex(automaton);
      expect(regex, equals('a'));
    });

    test('Two state parallel transitions produce union', () {
      final q0 = StateNode(id: 'q0', label: 'q0', position: Offset.zero, isInitial: true, isAccept: false);
      final q1 = StateNode(id: 'q1', label: 'q1', position: Offset.zero, isInitial: false, isAccept: true);
      final t1 = Transition(id: 't0', fromId: 'q0', toId: 'q1', symbols: {'a', 'b'});
      final automaton = Automaton(
        states: {'q0': q0, 'q1': q1},
        transitions: [t1],
      );

      final regex = RegexService.automatonToRegex(automaton);
      expect(regex, equals('a|b'));
    });

    test('Extracts valid regex from Binary Divisible by 3 preset', () {
      final dfa = ExampleAutomata.binaryDivisibleBy3.automaton;
      final regexStr = RegexService.automatonToRegex(dfa);
      expect(regexStr.isNotEmpty, isTrue);

      // Re-compile the extracted regex to NFA and verify it correctly
      // recognizes binary divisible by 3 strings!
      final recompiledNfa = RegexService.regexToAutomaton(regexStr);

      // Multiples of 3 in binary: 0 (0), 11 (3), 110 (6), 1001 (9)
      expect(AutomataSimulator.run(automaton: recompiledNfa, inputTape: '0').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: recompiledNfa, inputTape: '11').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: recompiledNfa, inputTape: '110').isStringAccepted, isTrue);
      expect(AutomataSimulator.run(automaton: recompiledNfa, inputTape: '1001').isStringAccepted, isTrue);

      // Non-multiples: 1 (1), 10 (2), 100 (4)
      expect(AutomataSimulator.run(automaton: recompiledNfa, inputTape: '1').isStringAccepted, isFalse);
      expect(AutomataSimulator.run(automaton: recompiledNfa, inputTape: '10').isStringAccepted, isFalse);
      expect(AutomataSimulator.run(automaton: recompiledNfa, inputTape: '100').isStringAccepted, isFalse);
    });

    test('Empty automaton returns empty set', () {
      final empty = Automaton();
      expect(RegexService.automatonToRegex(empty), equals('∅'));
    });
  });

  group('Bidirectional Round-Trip Tests', () {
    test('Regex -> NFA -> Regex preserves language acceptance', () {
      final patterns = ['(0|1)*1', 'ab*', 'a|b|c', '(01)+'];

      for (final p in patterns) {
        final nfa1 = RegexService.regexToAutomaton(p);
        final extractedRegex = RegexService.automatonToRegex(nfa1);
        final nfa2 = RegexService.regexToAutomaton(extractedRegex);

        // Verify nfa1 and nfa2 behave identically on test samples
        final testSamples = ['', 'a', 'b', 'c', '0', '1', '01', '10', '001', '101', 'abb', 'ab', '0101'];
        for (final sample in testSamples) {
          final res1 = AutomataSimulator.run(automaton: nfa1, inputTape: sample).isStringAccepted;
          final res2 = AutomataSimulator.run(automaton: nfa2, inputTape: sample).isStringAccepted;
          expect(
            res2,
            equals(res1),
            reason: 'Mismatch for pattern "$p" (extracted: "$extractedRegex") on string "$sample"',
          );
        }
      }
    });
  });

  group('StudioController Bidirectional Regex Sync Tests', () {
    test('Initializes with non-empty regex pattern for default machine', () {
      final controller = StudioController();
      expect(controller.regexPattern.isNotEmpty, isTrue);
      expect(controller.regexAutoSync, isTrue);
      expect(controller.regexError, isNull);
    });

    test('syncRegexToGraph updates automaton and simulator', () {
      final controller = StudioController();
      controller.setRegexPattern('(a|b)*abb', syncToGraph: true);

      expect(controller.regexError, isNull);
      expect(controller.automaton.states.isNotEmpty, isTrue);

      controller.setInputTape('ababb');
      expect(controller.simulator!.isStringAccepted, isTrue);

      controller.setInputTape('aba');
      expect(controller.simulator!.isStringAccepted, isFalse);
    });

    test('Graph mutations automatically update regex pattern when auto-sync is enabled', () {
      final controller = StudioController();
      final initialRegex = controller.regexPattern;
      expect(initialRegex, isNotEmpty);

      // Add a state to the machine
      controller.addStateAt(const Offset(500, 300));
      expect(controller.regexError, isNull);
      // Regex should have synced or updated
      expect(controller.isGraphOutOfSyncWithRegex, isFalse);
    });

    test('Auto-sync can be disabled and manually triggered', () {
      final controller = StudioController();
      controller.toggleRegexAutoSync(false);
      expect(controller.regexAutoSync, isFalse);

      final oldRegex = controller.regexPattern;
      expect(oldRegex, isNotEmpty);
      controller.addStateAt(const Offset(600, 300));

      expect(controller.isGraphOutOfSyncWithRegex, isTrue);

      controller.syncGraphToRegex();
      expect(controller.isGraphOutOfSyncWithRegex, isFalse);
    });

    test('Invalid regex records error message without disrupting current automaton', () {
      final controller = StudioController();
      final currentStatesCount = controller.automaton.states.length;

      controller.setRegexPattern('(a|b', syncToGraph: true);
      expect(controller.regexError, isNotNull);
      expect(controller.automaton.states.length, equals(currentStatesCount));
    });
  });
}
