import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/presentation/widgets/ui/video_playback_view.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../../support/test_harness.dart';

/// An in-memory [VideoPlayerPlatform]: no texture, no codec — the test
/// drives initialisation and errors by pushing [VideoEvent]s.
final class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> _events =
      <int, StreamController<VideoEvent>>{};
  int _nextPlayerId = 0;

  final List<Uri> createdSources = <Uri>[];
  final List<int> played = <int>[];
  final List<int> paused = <int>[];

  /// Pushes [event] to every live player.
  void emit(VideoEvent event) {
    for (final controller in _events.values) {
      controller.add(event);
    }
  }

  /// Fails every live player's event stream, the way a platform decoder
  /// error arrives.
  void emitError(Object error) {
    for (final controller in _events.values) {
      controller.addError(error);
    }
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++_nextPlayerId;
    _events[id] = StreamController<VideoEvent>.broadcast();
    createdSources.add(Uri.parse(options.dataSource.uri ?? ''));
    return id;
  }

  @override
  Future<void> dispose(int playerId) async {
    await _events.remove(playerId)?.close();
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> play(int playerId) async {
    played.add(playerId);
  }

  @override
  Future<void> pause(int playerId) async {
    paused.add(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}

void main() {
  late _FakeVideoPlayerPlatform platform;

  setUp(() {
    platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  final url = Uri.parse('https://photos.example.com/api/dl/tok');

  VideoEvent initialized() => VideoEvent(
    eventType: VideoEventType.initialized,
    duration: const Duration(seconds: 3),
    size: const Size(320, 240),
  );

  testWidgets('shows a spinner until the platform reports initialised', (
    tester,
  ) async {
    await pumpComponent(tester, VideoPlaybackView(url: url), settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(platform.createdSources, [url]);
  });

  testWidgets('plays automatically once initialised', (tester) async {
    await pumpComponent(tester, VideoPlaybackView(url: url), settle: false);
    await tester.pump();

    platform.emit(initialized());
    await tester.pump();
    await tester.pump();

    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.byType(VideoProgressIndicator), findsOneWidget);
    expect(platform.played, isNotEmpty);
  });

  testWidgets('tap pauses, tap again resumes', (tester) async {
    await pumpComponent(tester, VideoPlaybackView(url: url), settle: false);
    await tester.pump();
    platform.emit(initialized());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(VideoPlayer), warnIfMissed: false);
    await tester.pump();
    expect(platform.paused, isNotEmpty);

    await tester.tap(find.byType(VideoPlayer), warnIfMissed: false);
    await tester.pump();
    expect(platform.played.length, greaterThan(1));
  });

  testWidgets('a playback error renders the broken-video state', (
    tester,
  ) async {
    await pumpComponent(tester, VideoPlaybackView(url: url), settle: false);
    await tester.pump();

    platform.emitError(
      PlatformException(code: 'VideoError', message: 'codec died'),
    );
    await tester.pump();

    expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);
    expect(find.text('codec died'), findsNothing);
  });
}
