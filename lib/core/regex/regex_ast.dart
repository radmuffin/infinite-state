import 'package:flutter/foundation.dart';

/// Precedence levels for regex operators.
abstract class RegexPrecedence {
  static const int union = 1; // |
  static const int concat = 2; // implicit ab
  static const int postfix = 3; // *, +, ?
  static const int atom = 4; // literals, epsilon, empty set, parens
}

/// Abstract base class for all nodes in a Regular Expression AST.
@immutable
sealed class RegexNode {
  const RegexNode();

  int get precedence;

  /// Returns the canonical string representation of this regular expression.
  String toRegexString();

  /// Applies algebraic simplification rules to reduce expression complexity.
  RegexNode simplify();

  @override
  String toString() => toRegexString();
}

/// Represents the empty set language (∅), which recognizes no strings.
class RegexEmpty extends RegexNode {
  const RegexEmpty();

  @override
  int get precedence => RegexPrecedence.atom;

  @override
  String toRegexString() => '∅';

  @override
  RegexNode simplify() => this;

  @override
  bool operator ==(Object other) => other is RegexEmpty;

  @override
  int get hashCode => 0x13579BDF;
}

/// Represents the empty string language (ε), recognizing only the empty string.
class RegexEpsilon extends RegexNode {
  const RegexEpsilon();

  @override
  int get precedence => RegexPrecedence.atom;

  @override
  String toRegexString() => 'ε';

  @override
  RegexNode simplify() => this;

  @override
  bool operator ==(Object other) => other is RegexEpsilon;

  @override
  int get hashCode => 0x2468ACE0;
}

/// Represents a literal input symbol (e.g. '0', '1', 'a', 'b').
class RegexLiteral extends RegexNode {
  final String symbol;

  const RegexLiteral(this.symbol);

  @override
  int get precedence => RegexPrecedence.atom;

  @override
  String toRegexString() => symbol;

  @override
  RegexNode simplify() => this;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegexLiteral && other.symbol == symbol);

  @override
  int get hashCode => symbol.hashCode;
}

/// Represents the concatenation of one or more expressions (r₁r₂...rₙ).
class RegexConcat extends RegexNode {
  final List<RegexNode> children;

  const RegexConcat(this.children);

  @override
  int get precedence => RegexPrecedence.concat;

  @override
  String toRegexString() {
    if (children.isEmpty) return 'ε';
    if (children.length == 1) return children.first.toRegexString();

    final buffer = StringBuffer();
    for (final child in children) {
      if (child.precedence < precedence) {
        buffer.write('(${child.toRegexString()})');
      } else {
        buffer.write(child.toRegexString());
      }
    }
    return buffer.toString();
  }

  @override
  RegexNode simplify() {
    final simplifiedChildren = <RegexNode>[];

    for (final child in children) {
      final s = child.simplify();
      if (s is RegexEmpty) {
        // Any concatenation with ∅ results in ∅: r · ∅ = ∅
        return const RegexEmpty();
      } else if (s is RegexConcat) {
        // Flatten nested concatenations: (ab)c -> abc
        simplifiedChildren.addAll(s.children);
      } else if (s is RegexEpsilon) {
        // Drop epsilon unless list is empty: r · ε = r
        continue;
      } else {
        simplifiedChildren.add(s);
      }
    }

    if (simplifiedChildren.isEmpty) {
      return const RegexEpsilon();
    }
    if (simplifiedChildren.length == 1) {
      return simplifiedChildren.first;
    }
    return RegexConcat(List.unmodifiable(simplifiedChildren));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegexConcat && listEquals(other.children, children));

  @override
  int get hashCode => Object.hashAll(children);
}

/// Represents the union / alternation of expressions (r₁ | r₂ | ... | rₙ).
class RegexUnion extends RegexNode {
  final List<RegexNode> children;

  const RegexUnion(this.children);

  @override
  int get precedence => RegexPrecedence.union;

  @override
  String toRegexString() {
    if (children.isEmpty) return '∅';
    if (children.length == 1) return children.first.toRegexString();

    return children.map((c) {
      if (c.precedence < precedence) {
        return '(${c.toRegexString()})';
      }
      return c.toRegexString();
    }).join('|');
  }

  @override
  RegexNode simplify() {
    final collected = <RegexNode>[];

    void collect(RegexNode node) {
      final s = node.simplify();
      if (s is RegexUnion) {
        for (final child in s.children) {
          collect(child);
        }
      } else if (s is RegexEmpty) {
        // r | ∅ = r, drop empty set
      } else {
        collected.add(s);
      }
    }

    for (final child in children) {
      collect(child);
    }

    // Deduplicate identical terms: r | r = r
    final unique = <RegexNode>[];
    for (final node in collected) {
      if (!unique.contains(node)) {
        unique.add(node);
      }
    }

    // Check if union contains both R* and ε: R* | ε = R*
    final hasEpsilon = unique.any((n) => n is RegexEpsilon);
    if (hasEpsilon) {
      final hasStarCoveringEpsilon = unique.any((n) => n is RegexStar);
      if (hasStarCoveringEpsilon) {
        unique.removeWhere((n) => n is RegexEpsilon);
      }
    }

    if (unique.isEmpty) {
      return const RegexEmpty();
    }
    if (unique.length == 1) {
      return unique.first;
    }

    // Sort order for deterministic canonical string representation:
    // Literals first, then longer compounds, epsilon last
    unique.sort((a, b) {
      if (a is RegexEpsilon) return 1;
      if (b is RegexEpsilon) return -1;
      final strA = a.toRegexString();
      final strB = b.toRegexString();
      if (strA.length != strB.length) return strA.length.compareTo(strB.length);
      return strA.compareTo(strB);
    });

    return RegexUnion(List.unmodifiable(unique));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegexUnion && listEquals(other.children, children));

  @override
  int get hashCode => Object.hashAll(children);
}

/// Represents the Kleene star closure (r*), matching 0 or more repetitions.
class RegexStar extends RegexNode {
  final RegexNode child;

  const RegexStar(this.child);

  @override
  int get precedence => RegexPrecedence.postfix;

  @override
  String toRegexString() {
    if (child.precedence < precedence) {
      return '(${child.toRegexString()})*';
    }
    return '${child.toRegexString()}*';
  }

  @override
  RegexNode simplify() {
    final s = child.simplify();
    // ∅* = ε
    if (s is RegexEmpty) return const RegexEpsilon();
    // ε* = ε
    if (s is RegexEpsilon) return const RegexEpsilon();
    // (r*)* = r*
    if (s is RegexStar) return s;
    // (r+)* = r*
    if (s is RegexPlus) return RegexStar(s.child).simplify();
    // (r?)* = r*
    if (s is RegexOptional) return RegexStar(s.child).simplify();

    return RegexStar(s);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegexStar && other.child == child);

  @override
  int get hashCode => child.hashCode ^ 0x55555555;
}

/// Represents the positive closure (r+), matching 1 or more repetitions.
class RegexPlus extends RegexNode {
  final RegexNode child;

  const RegexPlus(this.child);

  @override
  int get precedence => RegexPrecedence.postfix;

  @override
  String toRegexString() {
    if (child.precedence < precedence) {
      return '(${child.toRegexString()})+';
    }
    return '${child.toRegexString()}+';
  }

  @override
  RegexNode simplify() {
    final s = child.simplify();
    if (s is RegexEmpty) return const RegexEmpty();
    if (s is RegexEpsilon) return const RegexEpsilon();
    if (s is RegexStar) return s; // (r*)+ = r*

    return RegexPlus(s);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegexPlus && other.child == child);

  @override
  int get hashCode => child.hashCode ^ 0xAAAAAAAA;
}

/// Represents an optional match (r?), matching 0 or 1 repetition (r | ε).
class RegexOptional extends RegexNode {
  final RegexNode child;

  const RegexOptional(this.child);

  @override
  int get precedence => RegexPrecedence.postfix;

  @override
  String toRegexString() {
    if (child.precedence < precedence) {
      return '(${child.toRegexString()})?';
    }
    return '${child.toRegexString()}?';
  }

  @override
  RegexNode simplify() {
    final s = child.simplify();
    if (s is RegexEmpty) return const RegexEpsilon();
    if (s is RegexEpsilon) return const RegexEpsilon();
    if (s is RegexStar) return s; // (r*)? = r*
    if (s is RegexOptional) return s; // (r?)? = r?

    return RegexOptional(s);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegexOptional && other.child == child);

  @override
  int get hashCode => child.hashCode ^ 0x33333333;
}
