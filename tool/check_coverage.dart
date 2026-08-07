// Coverage checker.
//
// Reads the lcov report produced by `flutter test --coverage` and enforces a
// per-layer floor as well as a project-wide one. Layer floors are the point:
// a project total can stay green while the Domain rules — the code with the
// most to lose from a regression — quietly rot.
//
// Usage:
//   dart run tool/check_coverage.dart [--lcov=<path>] [--verbose]
//
// Exits 0 when every threshold is met, 1 when one is missed, 2 when the
// report is missing or unreadable.

import 'dart:io';

/// A coverage floor, expressed as a percentage of executable lines hit.
class Threshold {
  const Threshold({
    required this.name,
    required this.pathPrefix,
    required this.minimumPercent,
  });

  final String name;

  /// Repository-relative prefix a source file must start with to count
  /// towards this threshold. Empty means "every file in the report".
  final String pathPrefix;

  final double minimumPercent;
}

/// Floors from `docs/ARCHITECTURE.md`. Raise them, never lower them.
const List<Threshold> _thresholds = [
  Threshold(name: 'Domain', pathPrefix: 'lib/domain/', minimumPercent: 90),
  Threshold(
    name: 'Application',
    pathPrefix: 'lib/application/',
    minimumPercent: 85,
  ),
  Threshold(name: 'Total', pathPrefix: '', minimumPercent: 80),
];

/// Line counts for one source file.
class _FileCoverage {
  _FileCoverage(this.path);

  final String path;
  int found = 0;
  int hit = 0;
}

void main(List<String> args) {
  var lcovPath = 'coverage/lcov.info';
  var verbose = false;
  for (final arg in args) {
    if (arg == '--verbose') {
      verbose = true;
    } else if (arg.startsWith('--lcov=')) {
      lcovPath = arg.substring('--lcov='.length);
    } else {
      stderr.writeln(
        'usage: dart run tool/check_coverage.dart '
        '[--lcov=<path>] [--verbose]',
      );
      exit(2);
    }
  }

  final lcov = File(lcovPath);
  if (!lcov.existsSync()) {
    stderr.writeln(
      'check_coverage: "$lcovPath" not found. '
      'Run `flutter test --coverage` first.',
    );
    exit(2);
  }

  final files = _parseLcov(lcov.readAsLinesSync());
  if (files.isEmpty) {
    stderr.writeln('check_coverage: "$lcovPath" contains no records.');
    exit(2);
  }

  var failed = false;
  final rows = <List<String>>[];

  for (final threshold in _thresholds) {
    final matching = files
        .where((f) => f.path.startsWith(threshold.pathPrefix))
        .toList();

    if (matching.isEmpty) {
      // A layer with no instrumented lines cannot be under-tested. Report it
      // rather than failing, so an empty starter layer does not block CI.
      rows.add([threshold.name, '—', '—', 'no instrumented lines', 'skip']);
      continue;
    }

    final found = matching.fold(0, (sum, f) => sum + f.found);
    final hit = matching.fold(0, (sum, f) => sum + f.hit);
    final percent = found == 0 ? 100.0 : hit / found * 100;
    final ok = percent + 1e-9 >= threshold.minimumPercent;
    if (!ok) failed = true;

    rows.add([
      threshold.name,
      '${percent.toStringAsFixed(1)}%',
      '${threshold.minimumPercent.toStringAsFixed(0)}%',
      '$hit/$found lines',
      ok ? 'ok' : 'FAIL',
    ]);

    if (!ok && verbose) {
      final worst = matching.where((f) => f.found > 0).toList()
        ..sort((a, b) => (a.hit / a.found).compareTo(b.hit / b.found));
      stdout.writeln('\nLeast-covered files in ${threshold.name}:');
      for (final file in worst.take(10)) {
        final filePercent = (file.hit / file.found * 100).toStringAsFixed(1);
        stdout.writeln(
          '  $filePercent%  ${file.path}  (${file.hit}/${file.found})',
        );
      }
    }
  }

  _printTable(rows);

  if (failed) {
    stderr.writeln(
      '\ncheck_coverage: coverage below the agreed floor. '
      'Add tests, or change the floor in tool/check_coverage.dart and say '
      'why in docs/adr/.',
    );
    exit(1);
  }
  stdout.writeln('check_coverage: OK — every threshold met.');
}

/// Parses the `SF` / `DA` / `LF` / `LH` records of an lcov report.
///
/// Line hits are recomputed from the `DA` records rather than trusted from
/// `LF`/`LH`, because a file can appear in more than one record when several
/// test files exercise it; summing `DA` per line number de-duplicates.
List<_FileCoverage> _parseLcov(List<String> lines) {
  final byPath = <String, _FileCoverage>{};
  final hitsByPath = <String, Map<int, int>>{};
  String? current;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      current = _normalise(line.substring(3).trim());
      byPath.putIfAbsent(current, () => _FileCoverage(current!));
      hitsByPath.putIfAbsent(current, () => <int, int>{});
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
      final lineNumber = int.tryParse(parts[0]);
      final count = int.tryParse(parts[1]);
      if (lineNumber == null || count == null) continue;
      final hits = hitsByPath[current]!;
      hits[lineNumber] = (hits[lineNumber] ?? 0) + count;
    } else if (line.startsWith('end_of_record')) {
      current = null;
    }
  }

  for (final entry in hitsByPath.entries) {
    final coverage = byPath[entry.key]!;
    coverage.found = entry.value.length;
    coverage.hit = entry.value.values.where((count) => count > 0).length;
  }

  return byPath.values.where((f) => f.found > 0).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Turns an lcov `SF:` path into a repository-relative one.
String _normalise(String path) {
  final unified = path.replaceAll(r'\', '/');
  final index = unified.indexOf('/lib/');
  if (index >= 0) return unified.substring(index + 1);
  return unified.startsWith('./') ? unified.substring(2) : unified;
}

void _printTable(List<List<String>> rows) {
  const headers = ['Layer', 'Actual', 'Floor', 'Lines', 'Result'];
  final all = [headers, ...rows];
  final widths = List<int>.generate(
    headers.length,
    (i) => all.map((r) => r[i].length).reduce((a, b) => a > b ? a : b),
  );

  String render(List<String> row) => row
      .asMap()
      .entries
      .map((e) => e.value.padRight(widths[e.key]))
      .join('  ')
      .trimRight();

  stdout
    ..writeln(render(headers))
    ..writeln(widths.map((w) => '-' * w).join('  '));
  for (final row in rows) {
    stdout.writeln(render(row));
  }
}
