import 'regex_ast.dart';

/// Exception thrown when a regular expression fails to parse.
class RegexParseException implements Exception {
  final String message;
  final int offset;

  RegexParseException(this.message, [this.offset = -1]);

  @override
  String toString() {
    if (offset >= 0) {
      return 'RegexParseException at position $offset: $message';
    }
    return 'RegexParseException: $message';
  }
}

enum _TokenType {
  literal,
  epsilon,
  empty,
  pipe,
  star,
  plus,
  question,
  lParen,
  rParen,
  implicitConcat,
}

class _Token {
  final _TokenType type;
  final String text;
  final int offset;

  const _Token(this.type, this.text, this.offset);

  @override
  String toString() => 'Token($type, "$text", offset: $offset)';
}

/// Recursive-descent parser for regular expressions supporting:
/// - Literals (alphanumeric, punctuation, escaped symbols like `\*`, `\|`)
/// - Concatenation (implicit, e.g. `ab`, `(a|b)c`)
/// - Alternation / Union (`|`)
/// - Postfix closures (`*`, `+`, `?`)
/// - Grouping (`(...)`)
/// - Epsilon (`ε`, `\e`, `eps`)
/// - Empty set (`∅`, `\0`)
class RegexParser {
  /// Parses [input] into a simplified [RegexNode] AST.
  static RegexNode parse(String input) {
    final tokens = _tokenize(input);
    if (tokens.isEmpty) {
      return const RegexEpsilon();
    }

    final parser = _Parser(tokens);
    final ast = parser.parseExpression();
    parser.ensureEof();
    return ast.simplify();
  }

  static List<_Token> _tokenize(String input) {
    final rawTokens = <_Token>[];
    int i = 0;

    while (i < input.length) {
      final ch = input[i];

      if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
        i++;
        continue;
      }

      if (ch == '\\') {
        if (i + 1 >= input.length) {
          throw RegexParseException('Dangling escape sequence at end of input', i);
        }
        final next = input[i + 1];
        if (next == 'e' || next == 'E') {
          rawTokens.add(_Token(_TokenType.epsilon, 'ε', i));
        } else if (next == '0') {
          rawTokens.add(_Token(_TokenType.empty, '∅', i));
        } else {
          // Escaped literal symbol
          rawTokens.add(_Token(_TokenType.literal, next, i));
        }
        i += 2;
        continue;
      }

      if (ch == '(') {
        rawTokens.add(_Token(_TokenType.lParen, '(', i));
        i++;
      } else if (ch == ')') {
        rawTokens.add(_Token(_TokenType.rParen, ')', i));
        i++;
      } else if (ch == '|') {
        rawTokens.add(_Token(_TokenType.pipe, '|', i));
        i++;
      } else if (ch == '*') {
        rawTokens.add(_Token(_TokenType.star, '*', i));
        i++;
      } else if (ch == '+') {
        rawTokens.add(_Token(_TokenType.plus, '+', i));
        i++;
      } else if (ch == '?') {
        rawTokens.add(_Token(_TokenType.question, '?', i));
        i++;
      } else if (ch == 'ε') {
        rawTokens.add(_Token(_TokenType.epsilon, 'ε', i));
        i++;
      } else if (ch == '∅') {
        rawTokens.add(_Token(_TokenType.empty, '∅', i));
        i++;
      } else {
        // Check for 'eps' keyword
        if (i + 3 <= input.length && input.substring(i, i + 3).toLowerCase() == 'eps') {
          rawTokens.add(_Token(_TokenType.epsilon, 'ε', i));
          i += 3;
          continue;
        }

        rawTokens.add(_Token(_TokenType.literal, ch, i));
        i++;
      }
    }

    if (rawTokens.isEmpty) return [];

    // Insert implicit concatenation tokens
    final tokensWithConcat = <_Token>[];
    for (int idx = 0; idx < rawTokens.length; idx++) {
      final curr = rawTokens[idx];
      tokensWithConcat.add(curr);

      if (idx + 1 < rawTokens.length) {
        final next = rawTokens[idx + 1];
        if (_canPrecedeConcat(curr.type) && _canFollowConcat(next.type)) {
          tokensWithConcat.add(_Token(_TokenType.implicitConcat, '·', next.offset));
        }
      }
    }

    return tokensWithConcat;
  }

  static bool _canPrecedeConcat(_TokenType type) {
    return type == _TokenType.literal ||
        type == _TokenType.epsilon ||
        type == _TokenType.empty ||
        type == _TokenType.rParen ||
        type == _TokenType.star ||
        type == _TokenType.plus ||
        type == _TokenType.question;
  }

  static bool _canFollowConcat(_TokenType type) {
    return type == _TokenType.literal ||
        type == _TokenType.epsilon ||
        type == _TokenType.empty ||
        type == _TokenType.lParen;
  }
}

class _Parser {
  final List<_Token> _tokens;
  int _current = 0;

  _Parser(this._tokens);

  bool get _isAtEnd => _current >= _tokens.length;

  _Token get _peek => _tokens[_current];

  _Token _advance() {
    if (!_isAtEnd) _current++;
    return _tokens[_current - 1];
  }

  bool _match(_TokenType type) {
    if (!_isAtEnd && _peek.type == type) {
      _advance();
      return true;
    }
    return false;
  }

  void ensureEof() {
    if (!_isAtEnd) {
      throw RegexParseException('Unexpected token "${_peek.text}"', _peek.offset);
    }
  }

  RegexNode parseExpression() => _parseUnion();

  // union -> concat ('|' concat)*
  RegexNode _parseUnion() {
    final list = <RegexNode>[_parseConcat()];

    while (_match(_TokenType.pipe)) {
      if (_isAtEnd || _peek.type == _TokenType.pipe || _peek.type == _TokenType.rParen) {
        // e.g. "a|" or "a||b" or "(a|)" -> matches epsilon on trailing branch
        list.add(const RegexEpsilon());
      } else {
        list.add(_parseConcat());
      }
    }

    if (list.length == 1) return list.first;
    return RegexUnion(list);
  }

  // concat -> postfix (implicitConcat postfix)*
  RegexNode _parseConcat() {
    final list = <RegexNode>[_parsePostfix()];

    while (_match(_TokenType.implicitConcat)) {
      list.add(_parsePostfix());
    }

    if (list.length == 1) return list.first;
    return RegexConcat(list);
  }

  // postfix -> atom ('*' | '+' | '?')*
  RegexNode _parsePostfix() {
    var node = _parseAtom();

    while (!_isAtEnd) {
      if (_match(_TokenType.star)) {
        node = RegexStar(node);
      } else if (_match(_TokenType.plus)) {
        node = RegexPlus(node);
      } else if (_match(_TokenType.question)) {
        node = RegexOptional(node);
      } else {
        break;
      }
    }

    return node;
  }

  // atom -> LITERAL | EPSILON | EMPTY | '(' expression ')'
  RegexNode _parseAtom() {
    if (_isAtEnd) {
      throw RegexParseException('Unexpected end of input, expected expression');
    }

    final token = _peek;

    if (_match(_TokenType.literal)) {
      return RegexLiteral(token.text);
    }

    if (_match(_TokenType.epsilon)) {
      return const RegexEpsilon();
    }

    if (_match(_TokenType.empty)) {
      return const RegexEmpty();
    }

    if (_match(_TokenType.lParen)) {
      if (_match(_TokenType.rParen)) {
        // () -> represents epsilon
        return const RegexEpsilon();
      }
      final inner = _parseUnion();
      if (!_match(_TokenType.rParen)) {
        throw RegexParseException('Mismatched opening parenthesis "("', token.offset);
      }
      return inner;
    }

    throw RegexParseException('Unexpected symbol "${token.text}"', token.offset);
  }
}
