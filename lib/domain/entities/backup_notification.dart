import 'package:photonest/domain/errors/app_error.dart';

/// The recorded outcome of one backup pass, shown in the notification list.
///
/// A pass that moved nothing records nothing — every notification stands for
/// at least one attempted upload. Two notifications are the same when their
/// [id] is the same.
final class BackupNotification {
  /// Validates the counts and normalises [occurredAt] to UTC.
  factory BackupNotification({
    required int id,
    required int uploadedCount,
    required int failedCount,
    required DateTime occurredAt,
    bool isRead = false,
  }) {
    if (uploadedCount < 0 || failedCount < 0) {
      throw const DomainError('Backup counts must not be negative.');
    }
    if (uploadedCount == 0 && failedCount == 0) {
      throw const DomainError(
        'A backup notification must stand for at least one upload attempt.',
      );
    }
    return BackupNotification._(
      id: id,
      uploadedCount: uploadedCount,
      failedCount: failedCount,
      occurredAt: occurredAt.toUtc(),
      isRead: isRead,
    );
  }

  const BackupNotification._({
    required this.id,
    required this.uploadedCount,
    required this.failedCount,
    required this.occurredAt,
    required this.isRead,
  });

  final int id;

  /// How many photos the pass uploaded successfully.
  final int uploadedCount;

  /// How many photos the pass could not upload.
  final int failedCount;

  /// When the pass finished, in UTC. Display converts to local time.
  final DateTime occurredAt;

  /// Whether the user has seen the notification list since it arrived.
  final bool isRead;

  /// Whether the pass left photos behind.
  bool get hasFailures => failedCount > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BackupNotification && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BackupNotification($id, +$uploadedCount/-$failedCount at $occurredAt)';
}
