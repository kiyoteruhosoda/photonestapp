@Tags(['tool'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// End-to-end tests for `tool/check_architecture.dart`.
///
/// A guard that cannot fail is not a guard. Each case writes a tiny fixture
/// tree containing one deliberate violation, runs the real checker against
/// it, and asserts on both the exit code and the rule that fired.

late Directory _fixtures;

/// Compiled once: `dart run` would re-analyse the checker for every case,
/// which dominates the runtime of this file.
late String _snapshot;

/// Writes [contents] to `<fixtures>/<name>/lib/<path>`.
void write(String root, String path, String contents) {
  final file = File('${_fixtures.path}/$root/lib/$path')
    ..parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

/// Runs the checker over `<fixtures>/<root>/lib`.
ProcessResult runChecker(String root) => Process.runSync('dart', [
  _snapshot,
  '--root=${_fixtures.path}/$root/lib',
  '--package=fixture',
]);

void main() {
  setUpAll(() {
    _fixtures = Directory.systemTemp.createTempSync('flutterbase_arch');
    _snapshot = '${_fixtures.path}/check_architecture.dill';
    final compiled = Process.runSync('dart', [
      'compile',
      'kernel',
      'tool/check_architecture.dart',
      '-o',
      _snapshot,
    ]);
    expect(
      compiled.exitCode,
      0,
      reason: 'could not compile the checker: ${compiled.stderr}',
    );
  });

  tearDownAll(() {
    if (_fixtures.existsSync()) _fixtures.deleteSync(recursive: true);
  });

  test('a clean tree passes with exit code 0', () {
    write('clean', 'domain/entities/order.dart', '''
final class Order {
  const Order(this.id);
  final String id;
}
''');
    write('clean', 'application/usecases/place_order.dart', '''
import 'package:fixture/domain/entities/order.dart';

final class PlaceOrder {
  const PlaceOrder();
  Order execute(String id) => Order(id);
}
''');

    final result = runChecker('clean');
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout, contains('OK'));
  });

  test('Domain importing Flutter is rejected', () {
    write('domain_flutter', 'domain/entities/order.dart', '''
import 'package:flutter/material.dart';

final class Order {
  const Order(this.colour);
  final Color colour;
}
''');

    final result = runChecker('domain_flutter');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('banned-import'));
  });

  test('Domain importing Infrastructure is rejected', () {
    write('domain_infra', 'infrastructure/order_api.dart', '''
final class OrderApi {
  const OrderApi();
}
''');
    write('domain_infra', 'domain/entities/order.dart', '''
import 'package:fixture/infrastructure/order_api.dart';

final class Order {
  const Order(this.api);
  final OrderApi api;
}
''');

    final result = runChecker('domain_infra');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('layer-direction'));
  });

  test('Application importing Presentation is rejected', () {
    write('app_presentation', 'presentation/order_page.dart', '''
final class OrderPage {
  const OrderPage();
}
''');
    write('app_presentation', 'application/usecases/place_order.dart', '''
import 'package:fixture/presentation/order_page.dart';

final class PlaceOrder {
  const PlaceOrder(this.page);
  final OrderPage page;
}
''');

    final result = runChecker('app_presentation');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('layer-direction'));
  });

  test('Infrastructure importing Presentation is rejected', () {
    write('infra_presentation', 'presentation/order_page.dart', '''
final class OrderPage {
  const OrderPage();
}
''');
    write('infra_presentation', 'infrastructure/order_api.dart', '''
import 'package:fixture/presentation/order_page.dart';

final class OrderApi {
  const OrderApi(this.page);
  final OrderPage page;
}
''');

    final result = runChecker('infra_presentation');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('layer-direction'));
  });

  test('Presentation using SharedPreferences directly is rejected', () {
    write('presentation_prefs', 'presentation/order_page.dart', '''
import 'package:shared_preferences/shared_preferences.dart';

final class OrderPage {
  const OrderPage(this.preferences);
  final SharedPreferences preferences;
}
''');

    final result = runChecker('presentation_prefs');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('banned-import'));
    expect(result.stderr, contains('infrastructure-only-type'));
  });

  test('using File outside Infrastructure is rejected', () {
    write('presentation_file', 'presentation/order_page.dart', '''
final class OrderPage {
  String read(dynamic file) => (file as Object).toString();
  Object make() => File('/tmp/x');
}

class File {
  File(this.path);
  final String path;
}
''');

    final result = runChecker('presentation_file');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('infrastructure-only-type'));
  });

  test('DateTime.now() in Domain is rejected', () {
    write('domain_clock', 'domain/entities/order.dart', '''
final class Order {
  Order();
  DateTime placedAt() => DateTime.now();
}
''');

    final result = runChecker('domain_clock');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('domain-clock'));
  });

  test('print() in Domain is rejected', () {
    write('domain_print', 'domain/entities/order.dart', '''
final class Order {
  const Order();
  void describe() {
    print('order');
  }
}
''');

    final result = runChecker('domain_print');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('domain-console-output'));
  });

  test('debugPrint() in Domain is rejected', () {
    write('domain_debug_print', 'domain/entities/order.dart', '''
final class Order {
  const Order();
  void describe() {
    debugPrint('order');
  }
}

void debugPrint(String message) {}
''');

    final result = runChecker('domain_debug_print');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('domain-console-output'));
  });

  test('a Domain type extending ChangeNotifier is rejected', () {
    write('domain_notifier', 'domain/entities/order.dart', '''
class ChangeNotifier {}

class Order extends ChangeNotifier {
  Order(this.id);
  final String id;
}
''');

    final result = runChecker('domain_notifier');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('domain-purity'));
  });

  test('a public setter on a Domain type is rejected', () {
    write('domain_setter', 'domain/entities/order.dart', '''
class Order {
  Order(this._id);
  String _id;
  String get id => _id;
  set id(String value) => _id = value;
}
''');

    final result = runChecker('domain_setter');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('domain-public-setter'));
  });

  test('a public mutable field on a Domain type is rejected', () {
    write('domain_field', 'domain/entities/order.dart', '''
class Order {
  Order(this.id);
  String id;
}
''');

    final result = runChecker('domain_field');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('implicit setter'));
  });

  test('a private mutable field on a Domain type is allowed', () {
    write('domain_private_field', 'domain/entities/order.dart', '''
class Order {
  Order(this._id);
  String _id;
  String get id => _id;
  void rename(String value) => _id = value;
}
''');

    final result = runChecker('domain_private_field');
    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('Application depending on a concrete adapter is rejected', () {
    write('app_concrete', 'infrastructure/sql_order_repository.dart', '''
final class SqlOrderRepository {
  const SqlOrderRepository();
}
''');
    write('app_concrete', 'application/usecases/place_order.dart', '''
final class PlaceOrder {
  const PlaceOrder(this.repository);
  final SqlOrderRepository repository;
}

class SqlOrderRepository {}
''');

    final result = runChecker('app_concrete');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('concrete-adapter-dependency'));
  });

  test('a file outside every layer is rejected', () {
    write('stray', 'helpers/order_helper.dart', '''
final class OrderHelper {
  const OrderHelper();
}
''');

    final result = runChecker('stray');
    expect(result.exitCode, 1);
    expect(result.stderr, contains('layer-placement'));
  });

  test('an unknown flag exits with the usage code', () {
    final result = Process.runSync('dart', [_snapshot, '--nope']);
    expect(result.exitCode, 2);
    expect(result.stderr, contains('usage:'));
  });

  test('a missing root exits with the usage code', () {
    final result = Process.runSync('dart', [
      _snapshot,
      '--root=${_fixtures.path}/does-not-exist',
    ]);
    expect(result.exitCode, 2);
  });
}
