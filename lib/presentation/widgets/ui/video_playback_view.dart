import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays one network video, with tap-to-pause and a scrub bar.
///
/// Owns the whole controller lifecycle: create on mount, dispose on unmount.
/// The URL is a signed, self-authorising address, so no headers or session
/// travel with it.
class VideoPlaybackView extends StatefulWidget {
  const VideoPlaybackView({required this.url, super.key});

  /// Absolute streaming URL.
  final Uri url;

  @override
  State<VideoPlaybackView> createState() => _VideoPlaybackViewState();
}

class _VideoPlaybackViewState extends State<VideoPlaybackView> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(widget.url)
      // Every value change repaints: initialisation completing, errors, and
      // the position ticks the scrub bar follows.
      ..addListener(_onControllerChanged);
    unawaited(_initializeAndPlay());
  }

  Future<void> _initializeAndPlay() async {
    try {
      await _controller.initialize();
      await _controller.play();
    } on Exception {
      // The controller's value now carries the error, and the listener
      // repaint renders the broken-video state — nothing more to do here.
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _togglePlayback() {
    if (_controller.value.isPlaying) {
      unawaited(_controller.pause());
    } else {
      unawaited(_controller.play());
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    if (value.hasError) {
      // The platform's message is developer-facing; the icon says enough,
      // and the surrounding screen already offers the way back.
      return Center(
        child: Icon(
          Icons.videocam_off_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (!value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return GestureDetector(
      onTap: _togglePlayback,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          VideoProgressIndicator(_controller, allowScrubbing: true),
        ],
      ),
    );
  }
}
