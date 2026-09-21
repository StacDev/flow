import 'package:flutter/foundation.dart';

import '../models/flow_message_part.dart';

/// The markdown engine behind `FlowMarkdown`: pure and synchronous, string
/// in and plain Dart values out, with no theme or widget knowledge — the
/// syntax highlighter's shape, applied to prose. No assets, no setup call,
/// safe to run in `build`.
///
/// The dialect is the pragmatic subset assistants actually emit: ATX
/// headings, fenced code, `>` quotes, nested lists, rules, pipe tables,
/// emphasis, strikethrough, inline code, `[label](href)` links, and
/// bare-URL autolinks (`https://`, `http://` and `www.` with GFM's
/// trimming rules; emails deliberately not). Setext headings, images,
/// task lists, footnotes and inline HTML are deliberately out — they
/// render as the literal text they are.
///
/// Built for streaming: input may end mid-construct at any character.
/// Unclosed delimiters stay literal until their closer arrives, an
/// unterminated fence is a code block still in progress, and a table only
/// becomes a table once its delimiter row lands — nothing renders broken,
/// and nothing renders wrong early.
abstract final class FlowMarkdownParser {
  /// Parses [source] into its block structure.
  ///
  /// Offsets on the returned blocks index into [source] after newline
  /// normalization, and are the identity a caller can use to recognize
  /// unchanged blocks between two parses of a growing source.
  static List<FlowMarkdownBlock> parseBlocks(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return _parseBlocks(_linesOf(normalized), 0);
  }

  /// Parses one leaf's stripped text into styled runs. Exposed for the
  /// leaf blocks' lazy caches; callers normally read `runs` on the block.
  static List<FlowMarkdownRun> parseInlines(String source) =>
      _parseInlines(source, null);

  // ---------------------------------------------------------------- blocks

  /// Containers stop nesting here; deeper markers render as the literal
  /// text they are. Assistants rarely exceed three levels.
  static const int _maxDepth = 6;

  static List<_Line> _linesOf(String source) {
    final lines = <_Line>[];
    var start = 0;
    while (start <= source.length) {
      final newline = source.indexOf('\n', start);
      if (newline == -1) {
        lines.add(_Line(start, source.substring(start)));
        break;
      }
      lines.add(_Line(start, source.substring(start, newline)));
      start = newline + 1;
    }
    return lines;
  }

  static List<FlowMarkdownBlock> _parseBlocks(List<_Line> lines, int depth) {
    final blocks = <FlowMarkdownBlock>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (_isBlank(line.text)) {
        i++;
        continue;
      }

      final marker = _dropIndent(line.text);

      final fence = _fenceOpen(marker);
      if (fence != null) {
        i = _readFence(lines, i, fence, blocks);
        continue;
      }

      final heading = _headingOf(line, marker);
      if (heading != null) {
        blocks.add(heading);
        i++;
        continue;
      }

      if (depth < _maxDepth && marker.startsWith('>')) {
        i = _readQuote(lines, i, depth, blocks);
        continue;
      }

      if (_containsPipe(marker) &&
          i + 1 < lines.length &&
          _isTableDelimiter(lines[i + 1].text)) {
        i = _readTable(lines, i, blocks);
        continue;
      }

      if (_isRule(marker)) {
        blocks.add(FlowMarkdownRuleBlock(line.start, _endOf(line)));
        i++;
        continue;
      }

      if (depth < _maxDepth) {
        final item = _listMarkerOf(line.text);
        if (item != null) {
          i = _readList(lines, i, item, depth, blocks);
          continue;
        }
      }

      i = _readParagraph(lines, i, depth, blocks);
    }
    return blocks;
  }

  static bool _isBlank(String text) => text.trim().isEmpty;

  static int _endOf(_Line line) => line.start + line.text.length;

  /// Up to three leading spaces are tolerated on any block marker.
  static String _dropIndent(String text) {
    var i = 0;
    while (i < text.length && i < 3 && text.codeUnitAt(i) == 0x20) {
      i++;
    }
    return text.substring(i);
  }

  // Fences ---------------------------------------------------------------

  static _FenceOpen? _fenceOpen(String text) {
    if (text.isEmpty) return null;
    final char = text[0];
    if (char != '`' && char != '~') return null;
    var length = 0;
    while (length < text.length && text[length] == char) {
      length++;
    }
    if (length < 3) return null;
    final info = text.substring(length).trim();
    // An info string with a backtick would be ambiguous with inline code.
    if (char == '`' && info.contains('`')) return null;
    final language = info.isEmpty ? null : info.split(_whitespaceRun).first;
    return _FenceOpen(char, length, language);
  }

  static int _readFence(
    List<_Line> lines,
    int index,
    _FenceOpen open,
    List<FlowMarkdownBlock> blocks,
  ) {
    final start = lines[index].start;
    final body = <String>[];
    var i = index + 1;
    var closed = false;
    var end = _endOf(lines[index]);
    while (i < lines.length) {
      final text = _dropIndent(lines[i].text);
      var run = 0;
      while (run < text.length && text[run] == open.char) {
        run++;
      }
      if (run >= open.length && text.substring(run).trim().isEmpty) {
        closed = true;
        end = _endOf(lines[i]);
        i++;
        break;
      }
      body.add(lines[i].text);
      end = _endOf(lines[i]);
      i++;
    }
    blocks.add(
      FlowMarkdownFence(
        start,
        end,
        code: body.join('\n'),
        language: open.language,
        closed: closed,
      ),
    );
    return i;
  }

  // Headings -------------------------------------------------------------

  /// Hoisted patterns — the parse re-runs over the whole document on
  /// every streaming delta, so per-call RegExp construction compounds.
  static final RegExp _whitespaceRun = RegExp(r'\s+');
  static final RegExp _closingHashes = RegExp(r'(^|\s)#+$');

  static FlowMarkdownHeading? _headingOf(_Line line, String marker) {
    var level = 0;
    while (level < marker.length && level < 6 && marker[level] == '#') {
      level++;
    }
    if (level == 0) return null;
    final rest = marker.substring(level);
    // "#hashtag" is prose, "# heading" and a bare "#" mid-stream are not.
    if (rest.isNotEmpty && !rest.startsWith(' ')) return null;
    var text = rest.trim();
    // A trailing run of #s is decoration, per ATX.
    final closing = _closingHashes.firstMatch(text);
    if (closing != null) text = text.substring(0, closing.start).trimRight();
    return FlowMarkdownHeading(line.start, _endOf(line), text, level: level);
  }

  // Rules ----------------------------------------------------------------

  static bool _isRule(String text) {
    final compact = text.replaceAll(' ', '').replaceAll('\t', '');
    if (compact.length < 3) return false;
    final char = compact[0];
    if (char != '-' && char != '*' && char != '_') return false;
    for (var i = 1; i < compact.length; i++) {
      if (compact[i] != char) return false;
    }
    return true;
  }

  // Quotes ---------------------------------------------------------------

  static int _readQuote(
    List<_Line> lines,
    int index,
    int depth,
    List<FlowMarkdownBlock> blocks,
  ) {
    final start = lines[index].start;
    final interior = <_Line>[];
    var i = index;
    var end = start;
    var offset = 0;
    while (i < lines.length) {
      final text = _dropIndent(lines[i].text);
      if (!text.startsWith('>')) break;
      var stripped = text.substring(1);
      if (stripped.startsWith(' ')) stripped = stripped.substring(1);
      interior.add(_Line(offset, stripped));
      offset += stripped.length + 1;
      end = _endOf(lines[i]);
      i++;
    }
    blocks.add(
      FlowMarkdownQuote(start, end, _parseBlocks(interior, depth + 1)),
    );
    return i;
  }

  // Tables ---------------------------------------------------------------

  static bool _containsPipe(String text) {
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '|' && (i == 0 || text[i - 1] != r'\')) return true;
    }
    return false;
  }

  static final RegExp _delimiterCell = RegExp(r'^\s*:?-+:?\s*$');

  static bool _isTableDelimiter(String text) {
    final body = _dropIndent(text);
    // Dashes make it a delimiter; the pipe keeps a bare `---` an hr.
    if (!body.contains('-') || !body.contains('|')) return false;
    final cells = _splitRow(body);
    if (cells.isEmpty) return false;
    for (final cell in cells) {
      if (!_delimiterCell.hasMatch(cell)) return false;
    }
    return true;
  }

  static List<String> _splitRow(String text) {
    var body = text.trim();
    if (body.startsWith('|')) body = body.substring(1);
    if (body.endsWith('|') &&
        (body.length < 2 || body[body.length - 2] != r'\')) {
      body = body.substring(0, body.length - 1);
    }
    final cells = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < body.length; i++) {
      final char = body[i];
      if (char == r'\' && i + 1 < body.length && body[i + 1] == '|') {
        buffer.write('|');
        i++;
      } else if (char == '|') {
        cells.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString().trim());
    return cells;
  }

  static int _readTable(
    List<_Line> lines,
    int index,
    List<FlowMarkdownBlock> blocks,
  ) {
    final start = lines[index].start;
    final header = [
      for (final cell in _splitRow(lines[index].text))
        FlowMarkdownTableCell(cell),
    ];
    final alignments = <FlowMarkdownAlign?>[
      for (final cell in _splitRow(_dropIndent(lines[index + 1].text)))
        _alignOf(cell),
    ];
    // The delimiter row is the table's shape; clamp alignments to it.
    while (alignments.length < header.length) {
      alignments.add(null);
    }
    if (alignments.length > header.length) {
      alignments.removeRange(header.length, alignments.length);
    }

    final rows = <List<FlowMarkdownTableCell>>[];
    var end = _endOf(lines[index + 1]);
    var i = index + 2;
    while (i < lines.length &&
        !_isBlank(lines[i].text) &&
        _containsPipe(lines[i].text)) {
      final cells = _splitRow(lines[i].text);
      // Rows keep the header's width: extra cells drop, missing render
      // empty — a partial trailing row mid-stream grows cell by cell.
      rows.add([
        for (var c = 0; c < header.length; c++)
          FlowMarkdownTableCell(c < cells.length ? cells[c] : ''),
      ]);
      end = _endOf(lines[i]);
      i++;
    }
    blocks.add(
      FlowMarkdownTable(
        start,
        end,
        header: header,
        alignments: alignments,
        rows: rows,
      ),
    );
    return i;
  }

  static FlowMarkdownAlign? _alignOf(String cell) {
    final body = cell.trim();
    final left = body.startsWith(':');
    final right = body.endsWith(':');
    if (left && right) return FlowMarkdownAlign.center;
    if (right) return FlowMarkdownAlign.right;
    if (left) return FlowMarkdownAlign.left;
    return null;
  }

  // Lists ----------------------------------------------------------------

  static final RegExp _bulletMarker = RegExp(r'^( {0,3})([-*+])( +|$)');
  static final RegExp _orderedMarker = RegExp(
    r'^( {0,3})(\d{1,9})([.)])( +|$)',
  );

  static _ListMarker? _listMarkerOf(String text) {
    final bullet = _bulletMarker.firstMatch(text);
    if (bullet != null) {
      // A rule ("- - -", "***") is never a list.
      if (_isRule(_dropIndent(text))) return null;
      final spaces = bullet.group(3)!;
      return _ListMarker(
        ordered: false,
        number: 1,
        contentColumn:
            bullet.group(1)!.length + 1 + (spaces.isEmpty ? 1 : spaces.length),
      );
    }
    final ordered = _orderedMarker.firstMatch(text);
    if (ordered != null) {
      final digits = ordered.group(2)!;
      final spaces = ordered.group(4)!;
      return _ListMarker(
        ordered: true,
        number: int.parse(digits),
        contentColumn:
            ordered.group(1)!.length +
            digits.length +
            1 +
            (spaces.isEmpty ? 1 : spaces.length),
      );
    }
    return null;
  }

  static int _readList(
    List<_Line> lines,
    int index,
    _ListMarker first,
    int depth,
    List<FlowMarkdownBlock> blocks,
  ) {
    final start = lines[index].start;
    final items = <FlowMarkdownListItem>[];
    var end = start;
    var i = index;
    List<_Line>? current;
    var contentColumn = first.contentColumn;
    // Interior offsets accumulate per item, like _readQuote's, so blocks
    // parsed inside the item keep the source-offset invariant
    // FlowMarkdownBlock documents (offsets index the item's normalized
    // source, not everything zero).
    var itemOffset = 0;

    void closeItem() {
      if (current != null) {
        items.add(FlowMarkdownListItem(_parseBlocks(current!, depth + 1)));
      }
      current = null;
    }

    while (i < lines.length) {
      final line = lines[i];
      if (_isBlank(line.text)) {
        // A blank ends the list unless the next content line is another
        // item of the same list, or a continuation of this item.
        var peek = i + 1;
        while (peek < lines.length && _isBlank(lines[peek].text)) {
          peek++;
        }
        if (peek >= lines.length) break;
        final next = lines[peek];
        final nextMarker = _listMarkerOf(next.text);
        final continuation = _indentOf(next.text) >= contentColumn;
        if ((nextMarker != null && nextMarker.ordered == first.ordered) ||
            continuation) {
          if (continuation && current != null) {
            current!.add(_Line(itemOffset, ''));
            itemOffset += 1;
          }
          i = peek;
          continue;
        }
        break;
      }

      final marker = _listMarkerOf(line.text);
      if (marker != null &&
          marker.ordered == first.ordered &&
          _indentOf(line.text) < contentColumn) {
        closeItem();
        contentColumn = marker.contentColumn;
        final text = line.text.length > contentColumn
            ? line.text.substring(contentColumn)
            : '';
        current = <_Line>[_Line(0, text)];
        itemOffset = text.length + 1;
        end = _endOf(line);
        i++;
        continue;
      }

      if (_indentOf(line.text) >= contentColumn && current != null) {
        final text = _stripColumns(line.text, contentColumn);
        current!.add(_Line(itemOffset, text));
        itemOffset += text.length + 1;
        end = _endOf(line);
        i++;
        continue;
      }

      break;
    }
    closeItem();

    blocks.add(
      FlowMarkdownList(
        start,
        end,
        ordered: first.ordered,
        startNumber: first.number,
        items: items,
      ),
    );
    return i;
  }

  static int _indentOf(String text) {
    var column = 0;
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (unit == 0x20) {
        column++;
      } else if (unit == 0x09) {
        column += 4 - column % 4;
      } else {
        return column;
      }
    }
    // All-whitespace lines count as arbitrarily indented continuations.
    return 1 << 20;
  }

  static String _stripColumns(String text, int columns) {
    var column = 0;
    var i = 0;
    while (i < text.length && column < columns) {
      final unit = text.codeUnitAt(i);
      if (unit == 0x20) {
        column++;
      } else if (unit == 0x09) {
        column += 4 - column % 4;
      } else {
        break;
      }
      i++;
    }
    return text.substring(i);
  }

  // Paragraphs -----------------------------------------------------------

  static int _readParagraph(
    List<_Line> lines,
    int index,
    int depth,
    List<FlowMarkdownBlock> blocks,
  ) {
    final start = lines[index].start;
    final body = <String>[lines[index].text.trim()];
    var end = _endOf(lines[index]);
    var i = index + 1;
    while (i < lines.length) {
      final text = lines[i].text;
      if (_isBlank(text)) break;
      final marker = _dropIndent(text);
      if (_fenceOpen(marker) != null) break;
      if (_headingOf(lines[i], marker) != null) break;
      if (marker.startsWith('>')) break;
      if (_isRule(marker)) break;
      if (depth < _maxDepth && _listMarkerOf(text) != null) break;
      if (_containsPipe(marker) &&
          i + 1 < lines.length &&
          _isTableDelimiter(lines[i + 1].text)) {
        break;
      }
      body.add(text.trim());
      end = _endOf(lines[i]);
      i++;
    }
    // A single newline renders as a line break — assistants use it as one,
    // and CommonMark's space-join would mangle their poems and addresses.
    blocks.add(FlowMarkdownParagraph(start, end, body.join('\n')));
    return i;
  }

  // ---------------------------------------------------------------- inlines

  static final RegExp _autolink = RegExp(r'^<(https?://[^\s<>]+)>');
  static const String _escapable = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~''';

  static List<FlowMarkdownRun> _parseInlines(
    String source,
    String? linkHref, {
    bool linkify = true,
  }) {
    final tokens = _tokenize(source);
    if (linkify) _linkifyTokens(tokens, source);
    _matchDelimiters(tokens);
    return _emitRuns(tokens, linkHref);
  }

  static List<_InlineToken> _tokenize(String source) {
    final tokens = <_InlineToken>[];
    final text = StringBuffer();
    var textStart = 0;

    void flush(int at) {
      if (text.isNotEmpty) {
        tokens.add(_TextToken(text.toString(), textStart));
        text.clear();
      }
      textStart = at;
    }

    var i = 0;
    while (i < source.length) {
      final char = source[i];

      if (char == r'\' &&
          i + 1 < source.length &&
          _escapable.contains(source[i + 1])) {
        // The escaped character starts its own run so the source mapping
        // stays 1:1 — the backslash is the dropped character.
        flush(i);
        tokens.add(_TextToken(source[i + 1], i + 1));
        i += 2;
        textStart = i;
        continue;
      }

      if (char == '`') {
        var open = 0;
        while (i + open < source.length && source[i + open] == '`') {
          open++;
        }
        final closer = _findBacktickRun(source, i + open, open);
        if (closer != -1) {
          flush(i);
          var span = source.substring(i + open, closer);
          var spanStart = i + open;
          // One space of padding strips when both sides carry it.
          if (span.length >= 2 && span.startsWith(' ') && span.endsWith(' ')) {
            span = span.substring(1, span.length - 1);
            spanStart++;
          }
          tokens.add(_CodeToken(span, spanStart));
          i = closer + open;
          textStart = i;
          continue;
        }
        text.write(source.substring(i, i + open));
        i += open;
        continue;
      }

      if (char == '<') {
        final match = _autolink.firstMatch(source.substring(i));
        if (match != null) {
          flush(i);
          final href = match.group(1)!;
          tokens.add(_LinkToken(href, i + 1, href: href, literalLabel: true));
          i += match.end;
          textStart = i;
          continue;
        }
      }

      if (char == '[') {
        final link = _readLink(source, i);
        if (link != null) {
          flush(i);
          tokens.add(link);
          i = link.consumed;
          textStart = i;
          continue;
        }
      }

      if (char == '*' || char == '_' || char == '~') {
        var length = 0;
        while (i + length < source.length && source[i + length] == char) {
          length++;
        }
        if (char == '~' && length < 2) {
          text.write(source.substring(i, i + length));
          i += length;
          continue;
        }
        final before = i == 0 ? null : source[i - 1];
        final after = i + length >= source.length ? null : source[i + length];
        var canOpen = after != null && after.trim().isNotEmpty;
        var canClose = before != null && before.trim().isNotEmpty;
        if (char == '_') {
          // Intraword underscores stay literal — snake_case survives.
          canOpen = canOpen && (before == null || !_isWordChar(before));
          canClose = canClose && (after == null || !_isWordChar(after));
        }
        if (!canOpen && !canClose) {
          text.write(source.substring(i, i + length));
          i += length;
          continue;
        }
        flush(i);
        tokens.add(
          _DelimiterToken(
            char,
            length,
            i,
            canOpen: canOpen,
            canClose: canClose,
          ),
        );
        i += length;
        textStart = i;
        continue;
      }

      text.write(char);
      i++;
    }
    flush(source.length);
    return tokens;
  }

  static int _findBacktickRun(String source, int from, int length) {
    var i = from;
    while (i < source.length) {
      if (source[i] != '`') {
        i++;
        continue;
      }
      var run = 0;
      while (i + run < source.length && source[i + run] == '`') {
        run++;
      }
      if (run == length) return i;
      i += run;
    }
    return -1;
  }

  /// `[label](href "title")` with one level of bracket nesting in the
  /// label and one level of parentheses in the href. A label whose `](`
  /// has arrived but whose `)` hasn't yet is the streaming case: the
  /// label renders (plain), the href stays hidden until it is whole.
  static _LinkToken? _readLink(String source, int from) {
    var depth = 0;
    var i = from + 1;
    while (i < source.length) {
      final char = source[i];
      if (char == r'\' && i + 1 < source.length) {
        i += 2;
        continue;
      }
      if (char == '[') {
        if (depth == 1) return null;
        depth++;
      } else if (char == ']') {
        if (depth == 0) break;
        depth--;
      }
      i++;
    }
    if (i >= source.length) return null;
    final label = source.substring(from + 1, i);
    if (i + 1 >= source.length || source[i + 1] != '(') return null;

    var j = i + 2;
    var parens = 0;
    while (j < source.length) {
      final char = source[j];
      if (char == r'\' && j + 1 < source.length) {
        j += 2;
        continue;
      }
      if (char == '(') {
        if (parens == 1) return null;
        parens++;
      } else if (char == ')') {
        if (parens == 0) {
          final target = source.substring(i + 2, j).trim();
          // A quoted title after the href is tolerated and dropped.
          final href = target.split(_whitespaceRun).first;
          return _LinkToken(label, from + 1, href: href, consumed: j + 1);
        }
        parens--;
      }
      j++;
    }
    // Unterminated: the label is content, the half-typed href is not.
    return _LinkToken(label, from + 1, href: null, consumed: source.length);
  }

  // Bare-URL autolinks ---------------------------------------------------

  /// GFM's trailing trim set for bare URLs; `;` doubles as the entity
  /// trigger.
  static const String _urlTrailingPunctuation = '?!.,:*_~;\'"';

  /// Splits bare `https://`, `http://` and `www.` URLs out of the token
  /// stream. Runs after tokenization, deliberately: emphasis markers are
  /// already delimiter tokens, so `**https://x.com**` presents a clean
  /// URL start — a pre-processing rewrite could never tell where the
  /// markdown ends and the URL begins. The URL's *extent* is measured in
  /// source space, and delimiter tokens falling wholly inside it are
  /// absorbed back into the link, so `wiki/Dart_(programming_language)`
  /// survives its underscore. Code spans and explicit links cap the
  /// extent; emails deliberately stay literal.
  static void _linkifyTokens(List<_InlineToken> tokens, String source) {
    for (var t = 0; t < tokens.length; t++) {
      final token = tokens[t];
      if (token is! _TextToken) continue;
      final text = token.text;

      // A candidate must start inside a text token.
      var i = 0;
      var found = -1;
      var prefix = 0;
      while (i < text.length) {
        final unit = text.codeUnitAt(i) | 0x20;
        if (unit == 0x68 || unit == 0x77) {
          prefix = _urlPrefixLength(text, i);
          if (prefix > 0 &&
              _canPrecedeAutolink(source, token.sourceStart + i)) {
            found = i;
            break;
          }
          i += prefix > 0 ? prefix : 1;
          continue;
        }
        i++;
      }
      if (found == -1) continue;

      final start = token.sourceStart + found;

      // Extent in source space, capped where the next atomic token
      // begins — a code span or an explicit link is never swallowed.
      var cap = source.length;
      for (var n = t + 1; n < tokens.length; n++) {
        final next = tokens[n];
        if (next is _TextToken || next is _DelimiterToken) continue;
        cap = switch (next) {
          _CodeToken(:final sourceStart) => sourceStart,
          _LinkToken(:final sourceStart) => sourceStart,
          _ => cap,
        };
        break;
      }
      var end = start + prefix;
      while (end < cap && !_isUrlStop(source.codeUnitAt(end))) {
        end++;
      }
      end = _trimmedUrlEnd(source, start, end);
      final www = prefix == 4;
      var valid = end > start + prefix;
      if (valid && www) {
        valid = _isValidWwwDomain(_domainOf(source, start, end));
      }
      if (!valid) continue;

      // Splice every token the URL range overlaps: text before the URL
      // stays, wholly-covered tokens are absorbed into the link, and a
      // partially-covered trailing text token keeps its tail.
      final pieces = <_InlineToken>[];
      if (found > 0) {
        pieces.add(_TextToken(text.substring(0, found), token.sourceStart));
      }
      final url = source.substring(start, end);
      pieces.add(
        _LinkToken(
          url,
          start,
          href: www ? 'https://$url' : url,
          literalLabel: true,
        ),
      );
      var last = t;
      while (last < tokens.length) {
        final covered = tokens[last];
        final coveredStart = switch (covered) {
          _TextToken(:final sourceStart) => sourceStart,
          _CodeToken(:final sourceStart) => sourceStart,
          _LinkToken(:final sourceStart) => sourceStart,
          _DelimiterToken(:final sourceStart) => sourceStart,
        };
        if (coveredStart >= end) break;
        if (covered is _TextToken && coveredStart + covered.text.length > end) {
          // The URL ends inside this text token; keep its tail.
          pieces.add(
            _TextToken(covered.text.substring(end - coveredStart), end),
          );
          last++;
          break;
        }
        last++;
      }
      tokens.replaceRange(t, last, pieces);
      // Land on the link piece, so the loop's increment continues at the
      // trailing text — which may hold another URL.
      t += found > 0 ? 1 : 0;
    }
  }

  static bool _isUrlStop(int unit) =>
      unit == 0x20 || unit == 0x09 || unit == 0x0A || unit == 0x3C;

  /// 8 for `https://`, 7 for `http://`, 4 for `www.` at [i]; 0
  /// otherwise. Case-insensitive.
  static int _urlPrefixLength(String text, int i) {
    bool match(String prefix) {
      if (i + prefix.length > text.length) return false;
      for (var k = 0; k < prefix.length; k++) {
        var unit = text.codeUnitAt(i + k);
        if (unit >= 0x41 && unit <= 0x5A) unit |= 0x20;
        if (unit != prefix.codeUnitAt(k)) return false;
      }
      return true;
    }

    if (match('https://')) return 8;
    if (match('http://')) return 7;
    if (match('www.')) return 4;
    return 0;
  }

  /// GFM's left flank: the start of input, or whitespace / `(` / `*` /
  /// `_` / `~` before the URL. Checked against the full source, so a URL
  /// at a token boundary (the `*` of `**https://…`) resolves correctly —
  /// and a preceding backtick or letter rejects.
  static bool _canPrecedeAutolink(String source, int sourceIndex) {
    if (sourceIndex <= 0) return true;
    final before = source[sourceIndex - 1];
    return before == ' ' ||
        before == '\t' ||
        before == '\n' ||
        before == '(' ||
        before == '*' ||
        before == '_' ||
        before == '~';
  }

  /// GFM's tail trim over `text[start, end)`: trailing punctuation, a
  /// `)` only while the URL holds more `)` than `(` — so a balanced
  /// wiki-style `(…)` stays — and a trailing `&entity;`.
  static int _trimmedUrlEnd(String text, int start, int end) {
    var open = 0;
    var close = 0;
    for (var i = start; i < end; i++) {
      final c = text[i];
      if (c == '(') open++;
      if (c == ')') close++;
    }
    while (end > start) {
      final c = text[end - 1];
      if (c == ')') {
        if (close > open) {
          end--;
          close--;
          continue;
        }
        break;
      }
      if (c == ';') {
        // `&amp;` and friends: alphanumerics between `&` and `;`.
        var k = end - 2;
        while (k > start && _isAlphanumeric(text.codeUnitAt(k))) {
          k--;
        }
        if (k >= start && text[k] == '&' && k < end - 2) {
          end = k;
        } else {
          end--;
        }
        continue;
      }
      if (_urlTrailingPunctuation.contains(c)) {
        end--;
        continue;
      }
      break;
    }
    return end;
  }

  static bool _isAlphanumeric(int unit) =>
      (unit >= 0x30 && unit <= 0x39) ||
      (unit >= 0x41 && unit <= 0x5A) ||
      (unit >= 0x61 && unit <= 0x7A);

  static String _domainOf(String text, int start, int end) {
    var i = start;
    while (i < end && _isDomainChar(text.codeUnitAt(i))) {
      i++;
    }
    return text.substring(start, i);
  }

  static bool _isDomainChar(int unit) =>
      _isAlphanumeric(unit) || unit == 0x2D || unit == 0x2E || unit == 0x5F;

  /// GFM's `www.` domain rule: two or more non-empty dot-separated
  /// segments, no underscore in the final two.
  static bool _isValidWwwDomain(String domain) {
    final segments = domain.split('.');
    if (segments.length < 2) return false;
    for (final segment in segments) {
      if (segment.isEmpty) return false;
    }
    if (segments[segments.length - 1].contains('_')) return false;
    if (segments[segments.length - 2].contains('_')) return false;
    return true;
  }

  static bool _isWordChar(String char) {
    final unit = char.codeUnitAt(0);
    return (unit >= 0x30 && unit <= 0x39) ||
        (unit >= 0x41 && unit <= 0x5A) ||
        (unit >= 0x61 && unit <= 0x7A) ||
        unit == 0x5F ||
        unit > 0x7F;
  }

  static void _matchDelimiters(List<_InlineToken> tokens) {
    final stack = <_DelimiterToken>[];
    for (final token in tokens) {
      if (token is! _DelimiterToken) continue;
      if (token.canClose) {
        while (token.remaining > 0) {
          _DelimiterToken? opener;
          for (var s = stack.length - 1; s >= 0; s--) {
            if (stack[s].char == token.char && stack[s].remaining > 0) {
              opener = stack[s];
              break;
            }
          }
          if (opener == null) break;
          final used = token.char == '~'
              ? 2
              : (opener.remaining >= 2 && token.remaining >= 2 ? 2 : 1);
          if (opener.remaining < used || token.remaining < used) break;
          final style = token.char == '~'
              ? _InlineStyle.strike
              : used == 2
              ? _InlineStyle.bold
              : _InlineStyle.italic;
          opener.opens.add(style);
          token.closes.add(style);
          opener.remaining -= used;
          token.remaining -= used;
          while (stack.isNotEmpty && stack.last.remaining == 0) {
            stack.removeLast();
          }
        }
      }
      if (token.canOpen && token.remaining > 0) stack.add(token);
    }
  }

  static List<FlowMarkdownRun> _emitRuns(
    List<_InlineToken> tokens,
    String? linkHref,
  ) {
    final runs = <FlowMarkdownRun>[];
    var bold = 0;
    var italic = 0;
    var strike = 0;

    void emit(String text, int sourceStart, {bool code = false, String? href}) {
      if (text.isEmpty) return;
      runs.add(
        FlowMarkdownRun(
          text: text,
          sourceStart: sourceStart,
          bold: bold > 0,
          italic: italic > 0,
          strike: strike > 0,
          code: code,
          linkHref: href ?? linkHref,
        ),
      );
    }

    for (final token in tokens) {
      switch (token) {
        case _TextToken(:final text, :final sourceStart):
          emit(text, sourceStart);
        case _CodeToken(:final text, :final sourceStart):
          emit(text, sourceStart, code: true);
        case _LinkToken(
          :final text,
          :final sourceStart,
          :final href,
          literalLabel: true,
        ):
          emit(text, sourceStart, href: href);
        case _LinkToken(:final text, :final sourceStart, :final href):
          // The label parses on its own, isolated from outer emphasis
          // pairing and never re-linkified — a bare URL inside a label
          // must not shadow the label's own href. Runs inherit the href,
          // or plainness mid-stream.
          for (final run in _parseInlines(text, href, linkify: false)) {
            runs.add(
              FlowMarkdownRun(
                text: run.text,
                sourceStart: sourceStart + run.sourceStart,
                bold: bold > 0 || run.bold,
                italic: italic > 0 || run.italic,
                strike: strike > 0 || run.strike,
                code: run.code,
                linkHref: run.linkHref,
              ),
            );
          }
        case _DelimiterToken():
          for (final style in token.closes) {
            switch (style) {
              case _InlineStyle.bold:
                bold--;
              case _InlineStyle.italic:
                italic--;
              case _InlineStyle.strike:
                strike--;
            }
          }
          if (token.remaining > 0) {
            emit(token.char * token.remaining, token.sourceStart);
          }
          for (final style in token.opens) {
            switch (style) {
              case _InlineStyle.bold:
                bold++;
              case _InlineStyle.italic:
                italic++;
              case _InlineStyle.strike:
                strike++;
            }
          }
      }
    }
    return runs;
  }
}

// ------------------------------------------------------------------- model

/// A block-level markdown node. [start] and [end] are offsets into the
/// normalized source the block was parsed from — equal offsets across two
/// parses of a growing source identify an unchanged block, which is how
/// the renderer reuses parsed instances (and their caches) mid-stream.
sealed class FlowMarkdownBlock {
  FlowMarkdownBlock(this.start, this.end);

  final int start;
  final int end;
}

/// A block carrying inline content. [source] is the stripped text —
/// markers removed, newlines kept — and [runs] parse lazily, cached on
/// the instance so reused blocks never re-parse.
sealed class FlowMarkdownLeafBlock extends FlowMarkdownBlock {
  FlowMarkdownLeafBlock(super.start, super.end, this.source);

  final String source;
  List<FlowMarkdownRun>? _runs;

  List<FlowMarkdownRun> get runs =>
      _runs ??= FlowMarkdownParser.parseInlines(source);
}

class FlowMarkdownParagraph extends FlowMarkdownLeafBlock {
  FlowMarkdownParagraph(super.start, super.end, super.source);
}

class FlowMarkdownHeading extends FlowMarkdownLeafBlock {
  FlowMarkdownHeading(
    super.start,
    super.end,
    super.source, {
    required this.level,
  });

  /// 1–6, from the ATX marker.
  final int level;
}

/// A fenced code block. [part] is synthesized eagerly so copy intent can
/// flow through the same `FlowCodePart` contract code parts use — and
/// because parsed instances are reused across deltas, `identical()`
/// copied-state matching keeps working for settled fences.
class FlowMarkdownFence extends FlowMarkdownBlock {
  FlowMarkdownFence(
    super.start,
    super.end, {
    required this.code,
    required this.language,
    required this.closed,
  }) : part = FlowCodePart(code, language: language);

  final String code;
  final String? language;

  /// False while the closing fence hasn't arrived — the streaming tail.
  final bool closed;

  final FlowCodePart part;
}

class FlowMarkdownQuote extends FlowMarkdownBlock {
  FlowMarkdownQuote(super.start, super.end, this.children);

  final List<FlowMarkdownBlock> children;
}

class FlowMarkdownList extends FlowMarkdownBlock {
  FlowMarkdownList(
    super.start,
    super.end, {
    required this.ordered,
    required this.startNumber,
    required this.items,
  });

  final bool ordered;

  /// The first marker's number; items then count up from it.
  final int startNumber;

  final List<FlowMarkdownListItem> items;
}

/// One list item — a container of blocks, not itself a block.
class FlowMarkdownListItem {
  FlowMarkdownListItem(this.children);

  final List<FlowMarkdownBlock> children;
}

class FlowMarkdownRuleBlock extends FlowMarkdownBlock {
  FlowMarkdownRuleBlock(super.start, super.end);
}

/// Column alignment from a table's delimiter row. Kept theme- and
/// Flutter-free, like everything the parser emits.
enum FlowMarkdownAlign { left, center, right }

class FlowMarkdownTable extends FlowMarkdownBlock {
  FlowMarkdownTable(
    super.start,
    super.end, {
    required this.header,
    required this.alignments,
    required this.rows,
  });

  final List<FlowMarkdownTableCell> header;

  /// Per column, from the delimiter row; null is the writer's default.
  final List<FlowMarkdownAlign?> alignments;

  final List<List<FlowMarkdownTableCell>> rows;
}

/// One table cell, with the leaf blocks' lazy run cache.
class FlowMarkdownTableCell {
  FlowMarkdownTableCell(this.source);

  final String source;
  List<FlowMarkdownRun>? _runs;

  List<FlowMarkdownRun> get runs =>
      _runs ??= FlowMarkdownParser.parseInlines(source);
}

/// One styled stretch of output text.
///
/// [text] maps 1:1 onto consecutive source characters starting at
/// [sourceStart] — the parser splits a run at every delimiter, escape and
/// dropped character so the mapping never skips inside a run. The
/// streaming reveal stamps characters by source offset, which is what
/// lets text restyle when a delimiter closes without re-fading.
@immutable
class FlowMarkdownRun {
  const FlowMarkdownRun({
    required this.text,
    required this.sourceStart,
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.code = false,
    this.linkHref,
  });

  final String text;
  final int sourceStart;
  final bool bold;
  final bool italic;
  final bool strike;

  /// An inline code span — mono face on the faint wash, emphasis-free.
  final bool code;

  /// Non-null inside a completed `[label](href)` link or a bare-URL
  /// autolink.
  final String? linkHref;
}

// ---------------------------------------------------------------- privates

class _Line {
  _Line(this.start, this.text);

  final int start;
  final String text;
}

class _FenceOpen {
  _FenceOpen(this.char, this.length, this.language);

  final String char;
  final int length;
  final String? language;
}

class _ListMarker {
  _ListMarker({
    required this.ordered,
    required this.number,
    required this.contentColumn,
  });

  final bool ordered;
  final int number;
  final int contentColumn;
}

enum _InlineStyle { bold, italic, strike }

sealed class _InlineToken {}

class _TextToken extends _InlineToken {
  _TextToken(this.text, this.sourceStart);

  final String text;
  final int sourceStart;
}

class _CodeToken extends _InlineToken {
  _CodeToken(this.text, this.sourceStart);

  final String text;
  final int sourceStart;
}

class _LinkToken extends _InlineToken {
  _LinkToken(
    this.text,
    this.sourceStart, {
    required this.href,
    int? consumed,
    this.literalLabel = false,
  }) : consumed = consumed ?? 0;

  /// True when [text] is the link itself (an autolink): emitted as one
  /// run without label re-parsing, so URL punctuation stays literal.
  final bool literalLabel;

  /// The label source, inline-parsed on emission.
  final String text;
  final int sourceStart;

  /// Null while the `)` hasn't streamed in — label renders plain.
  final String? href;

  /// Offset just past the construct, for the tokenizer's cursor.
  final int consumed;
}

class _DelimiterToken extends _InlineToken {
  _DelimiterToken(
    this.char,
    int length,
    this.sourceStart, {
    required this.canOpen,
    required this.canClose,
  }) : remaining = length;

  final String char;
  final int sourceStart;
  final bool canOpen;
  final bool canClose;

  int remaining;
  final List<_InlineStyle> opens = [];
  final List<_InlineStyle> closes = [];
}
