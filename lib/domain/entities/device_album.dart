import 'package:photonest/domain/errors/app_error.dart';

/// An album that exists on the device, as the backup-target choice sees it.
///
/// [id] is the platform's stable album identifier — it is what the backup
/// selection remembers, so renaming an album on the device does not clear
/// the choice. [name] and [itemCount] are descriptive: they exist so the
/// chooser can be read, not to identify the album.
final class DeviceAlbum {
  /// Throws [DomainError] when [id] is blank — an album that cannot be
  /// named back to the platform can neither be listed nor remembered.
  factory DeviceAlbum({
    required String id,
    required String name,
    required int itemCount,
  }) {
    if (id.trim().isEmpty) {
      throw const DomainError('DeviceAlbum id must not be blank.');
    }
    return DeviceAlbum._(id: id, name: name, itemCount: itemCount);
  }

  const DeviceAlbum._({
    required this.id,
    required this.name,
    required this.itemCount,
  });

  /// Platform album identifier, stable across app restarts.
  final String id;

  /// Album name as the device's gallery shows it.
  final String name;

  /// How many photos and videos the album holds.
  final int itemCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DeviceAlbum && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DeviceAlbum($id, $name, $itemCount)';
}
