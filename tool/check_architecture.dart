// Architecture checker.
//
// Enforces the layering rules in `docs/ARCHITECTURE.md` that the Dart
// analyzer cannot express. Every rule below is evaluated against the Dart
// AST produced by `package:analyzer` — never against raw text — so a rule
// fires on real syntax rather than on a substring that happens to appear in
// a comment or a string literal.
//
// Usage:
//   dart run tool/check_architecture.dart [--root=<dir>] [--package=<name>]
//                                         [--verbose]
//
// `--root` defaults to `lib` and `--package` to `flutterbase`; both exist so
// the checker's own tests can run it against fixture trees.
//
// Exits 0 when clean, 1 when any rule is violated, 2 on a usage error.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// The layers a source file can belong to.
enum Layer {
  domain('domain'),
  application('application'),
  infrastructure('infrastructure'),
  presentation('presentation'),

  /// Composition root: `lib/app/` and `lib/main.dart`. Allowed to see every
  /// layer at once, because wiring them together is its whole job.
  composition('app'),

  /// Framework-free constants shared by every layer. Depends on nothing.
  shared('shared');

  const Layer(this.label);

  final String label;
}

/// Which layers each layer may import from, itself included.
const Map<Layer, Set<Layer>> _allowedImports = <Layer, Set<Layer>>{
  Layer.domain: {Layer.domain, Layer.shared},
  Layer.application: {Layer.application, Layer.domain, Layer.shared},
  Layer.infrastructure: {
    Layer.infrastructure,
    Layer.application,
    Layer.domain,
    Layer.shared,
  },
  Layer.presentation: {
    Layer.presentation,
    Layer.application,
    Layer.domain,
    Layer.shared,
  },
  Layer.composition: {
    Layer.composition,
    Layer.presentation,
    Layer.infrastructure,
    Layer.application,
    Layer.domain,
    Layer.shared,
  },
  Layer.shared: {Layer.shared},
};

/// Package prefixes and `dart:` libraries each layer must not import.
///
/// Domain and Application stay pure Dart so their tests need no Flutter
/// binding and their rules stay portable. Everything that talks to a device,
/// a network, or a disk belongs to Infrastructure.
const Map<Layer, List<String>> _bannedUris = <Layer, List<String>>{
  Layer.domain: [
    'package:flutter/',
    'package:flutter_localizations/',
    'package:flutter_riverpod/',
    'package:go_router/',
    'package:get_it/',
    'dart:io',
    'dart:ui',
    'dart:html',
    'dart:js_interop',
    ..._ioPackages,
  ],
  Layer.application: [
    'package:flutter/',
    'package:flutter_localizations/',
    'package:flutter_riverpod/',
    'package:go_router/',
    'package:get_it/',
    'dart:io',
    'dart:ui',
    'dart:html',
    'dart:js_interop',
    ..._ioPackages,
  ],
  Layer.presentation: ['dart:io', ..._ioPackages],
  Layer.composition: ['dart:io', ..._ioPackages],
  Layer.shared: ['package:flutter/', 'dart:io', 'dart:ui', ..._ioPackages],
};

/// Packages that reach the network, a database, the file system, or platform
/// channels. Infrastructure is the only layer allowed to import them.
///
/// `url_launcher` is here for the same reason as the rest: handing a URL to
/// the platform is a plugin call, so it sits behind the
/// `ExternalLinkLauncher` port and its adapter in `infrastructure/links/`.
/// `package:path` is deliberately absent — it is pure string manipulation
/// with no platform behind it.
const List<String> _ioPackages = [
  'package:dio/',
  'package:http/',
  'package:sqflite/',
  'package:sqflite_common_ffi/',
  'package:shared_preferences/',
  'package:path_provider/',
  'package:package_info_plus/',
  'package:url_launcher/',
  'package:hive/',
  'package:drift/',
  'package:firebase_',
];

/// Type names that may only be named outside of a comment in Infrastructure.
///
/// Matched against type annotations, constructor invocations, and static
/// member access, so a local variable that merely shares a name is not
/// reported.
const Set<String> _infrastructureOnlyTypes = {
  'File',
  'Directory',
  'FileSystemEntity',
  'RandomAccessFile',
  'HttpClient',
  'Socket',
  'Dio',
  'MethodChannel',
  'EventChannel',
  'BasicMessageChannel',
  'SharedPreferences',
  'SharedPreferencesAsync',
  'Database',
};

/// Identifiers Domain must not call: they read ambient state (the clock) or
/// write to a console, both of which make domain rules untestable.
const Set<String> _domainBannedCalls = {'print', 'debugPrint'};

/// Base types a Domain type must not inherit from — Domain must not know
/// about Flutter's change-notification machinery.
const Set<String> _domainBannedSupertypes = {
  'ChangeNotifier',
  'ValueNotifier',
  'Listenable',
  'State',
  'StatelessWidget',
  'StatefulWidget',
  'Widget',
};

/// A single rule violation.
class Violation {
  Violation({
    required this.file,
    required this.line,
    required this.rule,
    required this.message,
  });

  final String file;
  final int line;
  final String rule;
  final String message;

  @override
  String toString() => '$file:$line  [$rule]\n    $message';
}

void main(List<String> args) {
  var root = 'lib';
  var package = 'flutterbase';
  var verbose = false;
  for (final arg in args) {
    if (arg == '--verbose') {
      verbose = true;
    } else if (arg.startsWith('--root=')) {
      root = arg.substring('--root='.length);
    } else if (arg.startsWith('--package=')) {
      package = arg.substring('--package='.length);
    } else {
      stderr.writeln(
        'usage: dart run tool/check_architecture.dart '
        '[--root=<dir>] [--package=<name>] [--verbose]',
      );
      exit(2);
    }
  }

  final rootDir = Directory(root);
  if (!rootDir.existsSync()) {
    stderr.writeln('check_architecture: no "$root" directory here.');
    exit(2);
  }

  final normalisedRoot = root
      .replaceAll(r'\', '/')
      .replaceAll(RegExp(r'/+$'), '');
  final files =
      rootDir
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.endsWith('.dart'))
          .where((p) => !p.endsWith('.g.dart') && !p.endsWith('.freezed.dart'))
          .toList()
        ..sort();

  if (files.isEmpty) {
    stderr.writeln('check_architecture: no Dart files under "$root".');
    exit(2);
  }

  // Parse once, reuse for the symbol index and for the per-file rules.
  final units = <String, CompilationUnit>{};
  for (final path in files) {
    units[path] = parseFile(
      path: path,
      featureSet: FeatureSet.latestLanguageVersion(),
    ).unit;
  }

  final layerOf = <String, Layer?>{
    for (final path in files) path: _layerOf(path, normalisedRoot),
  };
  final declaringLayerOf = _indexDeclarations(units, layerOf);
  final violations = <Violation>[];

  for (final entry in units.entries) {
    final path = entry.key;
    final layer = layerOf[path];
    if (layer == null) {
      violations.add(
        Violation(
          file: path,
          line: 1,
          rule: 'layer-placement',
          message:
              'File sits outside every known layer. Move it under '
              '$normalisedRoot/{domain,application,infrastructure,'
              'presentation,app,shared}/.',
        ),
      );
      continue;
    }
    _checkFile(
      path: path,
      layer: layer,
      package: package,
      unit: entry.value,
      declaringLayerOf: declaringLayerOf,
      violations: violations,
    );
  }

  _report(violations, files.length, verbose: verbose);
}

/// Maps every top-level type name declared under `lib/` to its layer.
///
/// Lets the checks below reason about "is this a concrete Infrastructure
/// class?" without needing full type resolution.
Map<String, Layer> _indexDeclarations(
  Map<String, CompilationUnit> units,
  Map<String, Layer?> layerOf,
) {
  final index = <String, Layer>{};
  for (final entry in units.entries) {
    final layer = layerOf[entry.key];
    if (layer == null) continue;
    for (final declaration in entry.value.declarations) {
      final name = switch (declaration) {
        final ClassDeclaration d => d.namePart.typeName.lexeme,
        final MixinDeclaration d => d.name.lexeme,
        final EnumDeclaration d => d.namePart.typeName.lexeme,
        final ExtensionTypeDeclaration d =>
          d.primaryConstructor.typeName.lexeme,
        final ClassTypeAlias d => d.name.lexeme,
        _ => null,
      };
      if (name != null) index[name] = layer;
    }
  }
  return index;
}

/// Returns the layer that owns [path] under [root], or null when it belongs
/// to none.
Layer? _layerOf(String path, String root) {
  if (!path.startsWith('$root/')) return null;
  final relative = path.substring(root.length + 1);
  if (relative == 'main.dart') return Layer.composition;
  for (final layer in Layer.values) {
    if (relative.startsWith('${layer.label}/')) return layer;
  }
  return null;
}

void _checkFile({
  required String path,
  required Layer layer,
  required String package,
  required CompilationUnit unit,
  required Map<String, Layer> declaringLayerOf,
  required List<Violation> violations,
}) {
  final lineInfo = unit.lineInfo;
  int lineOf(int offset) => lineInfo.getLocation(offset).lineNumber;

  // ── Import rules ────────────────────────────────────────────────────
  for (final directive in unit.directives) {
    final String uri;
    final int offset;
    switch (directive) {
      case final ImportDirective d:
        uri = d.uri.stringValue ?? '';
        offset = d.offset;
      case final ExportDirective d:
        uri = d.uri.stringValue ?? '';
        offset = d.offset;
      default:
        continue;
    }
    if (uri.isEmpty) continue;
    final line = lineOf(offset);

    // Rule: banned technology per layer.
    for (final banned in _bannedUris[layer] ?? const <String>[]) {
      if (uri == banned || uri.startsWith(banned)) {
        violations.add(
          Violation(
            file: path,
            line: line,
            rule: 'banned-import',
            message:
                '${layer.label} must not import "$uri". Move the code that '
                'needs it into lib/infrastructure/ and depend on a port.',
          ),
        );
      }
    }

    // Rule: layer direction, for imports inside this package.
    final target = _internalTargetLayer(uri, package);
    if (target == null) continue;
    final allowed = _allowedImports[layer] ?? const <Layer>{};
    if (!allowed.contains(target)) {
      violations.add(
        Violation(
          file: path,
          line: line,
          rule: 'layer-direction',
          message:
              '${layer.label} must not depend on ${target.label} '
              '("$uri").',
        ),
      );
    }
  }

  // ── AST rules ───────────────────────────────────────────────────────
  final visitor = _RuleVisitor(
    path: path,
    layer: layer,
    lineOf: lineOf,
    declaringLayerOf: declaringLayerOf,
    violations: violations,
  );
  unit.accept(visitor);
}

/// Returns the layer an in-package import points at, or null for third-party
/// and `dart:` URIs.
Layer? _internalTargetLayer(String uri, String package) {
  final prefix = 'package:$package/';
  if (!uri.startsWith(prefix)) return null;
  final relative = uri.substring(prefix.length);
  if (relative == 'main.dart') return Layer.composition;
  for (final layer in Layer.values) {
    if (relative.startsWith('${layer.label}/')) return layer;
  }
  return null;
}

/// Walks a compilation unit applying the rules that need syntax, not imports.
class _RuleVisitor extends RecursiveAstVisitor<void> {
  _RuleVisitor({
    required this.path,
    required this.layer,
    required this.lineOf,
    required this.declaringLayerOf,
    required this.violations,
  });

  final String path;
  final Layer layer;
  final int Function(int offset) lineOf;
  final Map<String, Layer> declaringLayerOf;
  final List<Violation> violations;

  void _add(int offset, String rule, String message) => violations.add(
    Violation(file: path, line: lineOf(offset), rule: rule, message: message),
  );

  // ── Rule: I/O and platform types outside Infrastructure ────────────
  void _checkInfrastructureOnlyType(String name, int offset) {
    if (layer == Layer.infrastructure) return;
    if (!_infrastructureOnlyTypes.contains(name)) return;
    _add(
      offset,
      'infrastructure-only-type',
      '"$name" may only be used in lib/infrastructure/. ${layer.label} '
          'should go through a port instead.',
    );
  }

  // ── Rule: concrete Infrastructure types outside their layer ────────
  void _checkConcreteDependency(String name, int offset) {
    final declaringLayer = declaringLayerOf[name];
    if (declaringLayer != Layer.infrastructure) return;
    if (layer == Layer.infrastructure || layer == Layer.composition) return;
    _add(
      offset,
      'concrete-adapter-dependency',
      '${layer.label} refers to the concrete adapter "$name". Depend on the '
          'Domain interface it implements; only the composition root may name '
          'an adapter.',
    );
  }

  @override
  void visitNamedType(NamedType node) {
    final name = node.name.lexeme;
    _checkInfrastructureOnlyType(name, node.offset);
    _checkConcreteDependency(name, node.offset);
    super.visitNamedType(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.type.name.lexeme;
    _checkInfrastructureOnlyType(name, node.offset);
    _checkConcreteDependency(name, node.offset);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final target = node.prefix.name;
    _checkInfrastructureOnlyType(target, node.offset);
    _checkConcreteDependency(target, node.offset);

    // Rule: Domain must not read the ambient clock.
    if (layer == Layer.domain &&
        target == 'DateTime' &&
        node.identifier.name == 'now') {
      _add(
        node.offset,
        'domain-clock',
        'Domain must not call DateTime.now(). Take the instant as a '
            'parameter so the rule stays deterministic under test.',
      );
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target is SimpleIdentifier) {
      _checkInfrastructureOnlyType(target.name, node.offset);
      _checkConcreteDependency(target.name, node.offset);
      if (layer == Layer.domain &&
          target.name == 'DateTime' &&
          node.methodName.name == 'now') {
        _add(
          node.offset,
          'domain-clock',
          'Domain must not call DateTime.now(). Take the instant as a '
              'parameter so the rule stays deterministic under test.',
        );
      }
    }

    if (target == null) {
      // An unresolved AST cannot tell `File('x')` from a function call, so a
      // constructor invoked without `new` arrives here rather than at
      // visitInstanceCreationExpression.
      _checkInfrastructureOnlyType(node.methodName.name, node.offset);
      _checkConcreteDependency(node.methodName.name, node.offset);

      // Rule: Domain must not write to a console.
      if (layer == Layer.domain &&
          _domainBannedCalls.contains(node.methodName.name)) {
        _add(
          node.offset,
          'domain-console-output',
          'Domain must not call ${node.methodName.name}(). Report through a '
              'return value or an Application-level port.',
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (layer == Layer.domain) {
      _checkDomainSupertypes(node);
      _checkDomainMutability(node);
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    if (layer == Layer.domain) {
      for (final member in node.body.members) {
        _checkDomainMember(member, node.name.lexeme);
      }
    }
    super.visitMixinDeclaration(node);
  }

  /// Rule: no Domain type may inherit Flutter's notification machinery.
  void _checkDomainSupertypes(ClassDeclaration node) {
    final supertypes = <NamedType>[
      if (node.extendsClause?.superclass case final NamedType s) s,
      ...?node.withClause?.mixinTypes,
      ...?node.implementsClause?.interfaces,
    ];
    for (final supertype in supertypes) {
      final name = supertype.name.lexeme;
      if (!_domainBannedSupertypes.contains(name)) continue;
      _add(
        supertype.offset,
        'domain-purity',
        '"${node.namePart.typeName.lexeme}" must not derive from "$name". '
            'Domain types '
            'are plain Dart; put change notification in a Presentation '
            'ViewModel.',
      );
    }
  }

  /// Rule: Domain types expose no public setter and no public mutable field.
  ///
  /// Both let a caller move an entity into a state its own invariants never
  /// approved. State changes belong in named methods.
  void _checkDomainMutability(ClassDeclaration node) {
    for (final member in node.body.members) {
      _checkDomainMember(member, node.namePart.typeName.lexeme);
    }
  }

  void _checkDomainMember(ClassMember member, String owner) {
    if (member is MethodDeclaration) {
      if (member.isSetter &&
          !member.isStatic &&
          !member.name.lexeme.startsWith('_')) {
        _add(
          member.offset,
          'domain-public-setter',
          '"$owner.${member.name.lexeme}" is a public setter. Replace it '
              'with an intention-revealing method that upholds the '
              'invariants.',
        );
      }
      return;
    }
    if (member is! FieldDeclaration || member.isStatic) return;
    if (member.fields.isFinal || member.fields.isConst) return;
    for (final variable in member.fields.variables) {
      if (variable.name.lexeme.startsWith('_')) continue;
      _add(
        variable.offset,
        'domain-public-setter',
        '"$owner.${variable.name.lexeme}" is a public mutable field, so it '
            'carries an implicit setter. Make it final.',
      );
    }
  }
}

void _report(
  List<Violation> violations,
  int fileCount, {
  required bool verbose,
}) {
  if (violations.isEmpty) {
    stdout.writeln('check_architecture: OK — $fileCount files, no violations.');
    return;
  }

  violations.sort((a, b) {
    final byFile = a.file.compareTo(b.file);
    return byFile != 0 ? byFile : a.line.compareTo(b.line);
  });

  stderr.writeln(
    'check_architecture: ${violations.length} violation(s) '
    'in $fileCount files.\n',
  );
  for (final violation in violations) {
    stderr.writeln(violation);
  }

  final byRule = <String, int>{};
  for (final violation in violations) {
    byRule[violation.rule] = (byRule[violation.rule] ?? 0) + 1;
  }
  stderr.writeln('\nBy rule:');
  for (final entry in byRule.entries) {
    stderr.writeln('  ${entry.key}: ${entry.value}');
  }
  if (verbose) {
    stderr.writeln('\nSee docs/ARCHITECTURE.md for the rationale per rule.');
  }
  exit(1);
}
