// Dependency checker.
//
// Where `check_architecture.dart` polices the arrows *inside* a package,
// this one polices the package graph itself:
//
//   1. Every `package:` URI imported from `lib/` is declared in
//      `pubspec.yaml`, and every declared runtime dependency is either
//      imported by `lib/` or listed under `dependency_policy.reserved`, so
//      the manifest stays honest about what the app actually uses.
//   2. If the layers have been split into separate Dart packages under
//      `packages/`, each package's own `pubspec.yaml` obeys the same
//      dependency direction as the single-package layout. This is a no-op
//      until such a split happens — see docs/adr/0001.
//
// Usage:
//   dart run tool/check_dependencies.dart [--verbose]
//
// Exits 0 when clean, 1 on a violation, 2 on a usage error.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Layer directory names, innermost first.
const List<String> _layers = [
  'domain',
  'application',
  'infrastructure',
  'presentation',
];

/// Which layer packages a layer package may depend on, for the multi-package
/// layout. Presentation and Infrastructure are siblings: neither may see the
/// other.
const Map<String, Set<String>> _allowedLayerPackageDeps = {
  'domain': <String>{},
  'application': {'domain'},
  'infrastructure': {'domain', 'application'},
  'presentation': {'domain', 'application'},
};

/// Dependencies that exist for tooling rather than for `lib/` code, so an
/// "unused runtime dependency" report on them would be a false positive.
const Set<String> _toolingDependencies = {
  'flutter',
  'flutter_localizations',
  'flutter_test',
  'integration_test',
};

/// Top-level pubspec key holding the reserved-dependency allowlist.
///
/// This repository is a template, so it ships a starter stack that the
/// generated app is expected to reach for (routing, state management, SQLite,
/// …) before any of it is imported here. Listing those packages under
/// `dependency_policy.reserved` records that the absence of imports is a
/// deliberate choice rather than an oversight — an accidental unused
/// dependency still fails the check.
const String _policyKey = 'dependency_policy';

class Violation {
  Violation(this.rule, this.message);

  final String rule;
  final String message;

  @override
  String toString() => '  [$rule] $message';
}

void main(List<String> args) {
  final verbose = args.contains('--verbose');
  if (args.any((a) => a != '--verbose')) {
    stderr.writeln('usage: dart run tool/check_dependencies.dart [--verbose]');
    exit(2);
  }

  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('check_dependencies: no pubspec.yaml here.');
    exit(2);
  }

  final violations = <Violation>[
    ..._checkRootManifest(pubspec, verbose: verbose),
    ..._checkLayerPackages(verbose: verbose),
  ];

  if (violations.isEmpty) {
    stdout.writeln('check_dependencies: OK — no violations.');
    return;
  }

  stderr.writeln('check_dependencies: ${violations.length} violation(s).\n');
  for (final violation in violations) {
    stderr.writeln(violation);
  }
  exit(1);
}

// ─── Root manifest ────────────────────────────────────────────────────────

List<Violation> _checkRootManifest(File pubspec, {required bool verbose}) {
  final manifest = _Manifest.parse(pubspec.readAsLinesSync());
  final imported = _importedPackages(Directory('lib'));
  final violations = <Violation>[];

  final declared = {...manifest.dependencies, ...manifest.devDependencies};
  for (final package in imported.difference(declared)) {
    if (package == manifest.name) continue;
    violations.add(
      Violation(
        'undeclared-dependency',
        'lib/ imports "package:$package/…" but pubspec.yaml does not declare '
            '$package.',
      ),
    );
  }

  final unused = manifest.dependencies
      .difference(imported)
      .difference(_toolingDependencies)
      .difference(manifest.reserved);
  for (final package in unused) {
    violations.add(
      Violation(
        'unused-dependency',
        '"$package" is a runtime dependency but nothing under lib/ imports '
            'it. Remove it, move it to dev_dependencies if only tooling '
            'needs it, or list it under $_policyKey.reserved if the template '
            'ships it on purpose.',
      ),
    );
  }

  // A reservation that has been made good on is stale bookkeeping.
  for (final package in manifest.reserved.intersection(imported)) {
    violations.add(
      Violation(
        'stale-reservation',
        '"$package" is listed under $_policyKey.reserved but lib/ now '
            'imports it. Drop the reservation.',
      ),
    );
  }
  for (final package in manifest.reserved.difference(manifest.dependencies)) {
    violations.add(
      Violation(
        'stale-reservation',
        '"$package" is listed under $_policyKey.reserved but is not a '
            'declared dependency. Drop the reservation.',
      ),
    );
  }

  if (verbose) {
    stdout.writeln(
      'check_dependencies: ${declared.length} declared, '
      '${imported.length} imported from lib/.',
    );
  }
  return violations;
}

/// Every `package:<name>/…` URI imported or exported from Dart files under
/// [root].
Set<String> _importedPackages(Directory root) {
  if (!root.existsSync()) return <String>{};
  final packages = <String>{};
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    final unit = parseFile(
      path: file.path,
      featureSet: FeatureSet.latestLanguageVersion(),
    ).unit;
    for (final directive in unit.directives) {
      final uri = switch (directive) {
        final ImportDirective d => d.uri.stringValue,
        final ExportDirective d => d.uri.stringValue,
        _ => null,
      };
      if (uri == null || !uri.startsWith('package:')) continue;
      final rest = uri.substring('package:'.length);
      final slash = rest.indexOf('/');
      if (slash > 0) packages.add(rest.substring(0, slash));
    }
  }
  return packages;
}

// ─── Optional multi-package layout ────────────────────────────────────────

/// Verifies `packages/<layer>/pubspec.yaml` files when the layers have been
/// split into separate Dart packages.
///
/// A layer package must not declare a dependency on a layer further out than
/// itself, and must not declare Flutter at all when it is Domain or
/// Application.
List<Violation> _checkLayerPackages({required bool verbose}) {
  final packagesDir = Directory('packages');
  if (!packagesDir.existsSync()) {
    if (verbose) {
      stdout.writeln(
        'check_dependencies: single-package layout — no packages/ directory.',
      );
    }
    return const <Violation>[];
  }

  final violations = <Violation>[];
  for (final entry in packagesDir.listSync().whereType<Directory>()) {
    final name = entry.path.split(Platform.pathSeparator).last;
    final layer = _layers.firstWhere(
      (l) => name == l || name.endsWith('_$l'),
      orElse: () => '',
    );
    if (layer.isEmpty) continue;

    final manifest = File('${entry.path}/pubspec.yaml');
    if (!manifest.existsSync()) {
      violations.add(
        Violation('missing-manifest', 'packages/$name has no pubspec.yaml.'),
      );
      continue;
    }

    final parsed = _Manifest.parse(manifest.readAsLinesSync());
    final allowed = _allowedLayerPackageDeps[layer] ?? const <String>{};

    for (final dependency in parsed.dependencies) {
      final dependencyLayer = _layers.firstWhere(
        (l) => dependency == l || dependency.endsWith('_$l'),
        orElse: () => '',
      );
      if (dependencyLayer.isNotEmpty &&
          !allowed.contains(dependencyLayer) &&
          dependencyLayer != layer) {
        violations.add(
          Violation(
            'package-direction',
            'packages/$name ($layer) depends on "$dependency" '
                '($dependencyLayer). Allowed: '
                '${allowed.isEmpty ? "none" : allowed.join(", ")}.',
          ),
        );
      }
      if ((layer == 'domain' || layer == 'application') &&
          (dependency == 'flutter' || dependency.startsWith('flutter_'))) {
        violations.add(
          Violation(
            'package-direction',
            'packages/$name ($layer) declares "$dependency". Domain and '
                'Application stay pure Dart.',
          ),
        );
      }
    }
  }
  return violations;
}

// ─── Minimal pubspec reader ───────────────────────────────────────────────

/// Just enough YAML for a pubspec's shape: a name, two dependency maps whose
/// keys sit exactly two spaces in, and the reserved-dependency list.
///
/// Deliberately not a general YAML parser — this reads a file the repository
/// controls, and keeping it dependency-free means the check runs before
/// `pub get` has ever succeeded.
class _Manifest {
  _Manifest({
    required this.name,
    required this.dependencies,
    required this.devDependencies,
    required this.reserved,
  });

  factory _Manifest.parse(List<String> lines) {
    var name = '';
    final dependencies = <String>{};
    final devDependencies = <String>{};
    final reserved = <String>{};
    String? section;
    var inReserved = false;

    final keyPattern = RegExp(r'^  ([A-Za-z0-9_]+):');
    final itemPattern = RegExp(r'^\s*-\s+([A-Za-z0-9_]+)\s*$');
    for (final line in lines) {
      if (line.trimLeft().startsWith('#')) continue;

      if (line.startsWith('name:')) {
        name = line.substring('name:'.length).trim();
        continue;
      }
      if (!line.startsWith(' ') && line.trimRight().endsWith(':')) {
        section = line.trimRight().replaceAll(':', '');
        inReserved = false;
        continue;
      }
      if (section == _policyKey) {
        if (line.startsWith('  reserved:')) {
          inReserved = true;
          continue;
        }
        if (inReserved) {
          final item = itemPattern.firstMatch(line);
          if (item != null) {
            reserved.add(item.group(1)!);
            continue;
          }
          inReserved = false;
        }
        continue;
      }
      final match = keyPattern.firstMatch(line);
      if (match == null) continue;
      final key = match.group(1)!;
      switch (section) {
        case 'dependencies':
          dependencies.add(key);
        case 'dev_dependencies':
          devDependencies.add(key);
      }
    }
    return _Manifest(
      name: name,
      dependencies: dependencies,
      devDependencies: devDependencies,
      reserved: reserved,
    );
  }

  final String name;
  final Set<String> dependencies;
  final Set<String> devDependencies;

  /// Runtime dependencies the template ships on purpose but does not import.
  final Set<String> reserved;
}
