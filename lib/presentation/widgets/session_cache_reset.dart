import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/presentation/providers/album_providers.dart';
import 'package:flutterbase/presentation/providers/upload_providers.dart';
import 'package:flutterbase/presentation/viewmodels/session_viewmodel.dart';

/// Drops every server-derived Riverpod cache when the signed-in identity
/// changes.
///
/// The screen providers are root-scoped (they deliberately outlive
/// navigation), so without this a logout followed by a login to another
/// server or account would keep showing the previous identity's albums and
/// thumbnails. Sits directly under the root `ProviderScope`, above the
/// router.
///
/// Only the *identity* matters: a transparent token rotation changes the
/// session object but not whose data is on screen, and must not blow the
/// caches every hour.
class SessionCacheReset extends ConsumerStatefulWidget {
  const SessionCacheReset({
    required this.sessionViewModel,
    required this.child,
    super.key,
  });

  final SessionViewModel sessionViewModel;
  final Widget child;

  @override
  ConsumerState<SessionCacheReset> createState() => _SessionCacheResetState();
}

class _SessionCacheResetState extends ConsumerState<SessionCacheReset> {
  late (String?, Uri?) _identity;

  @override
  void initState() {
    super.initState();
    _identity = _currentIdentity();
    widget.sessionViewModel.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.sessionViewModel.removeListener(_onSessionChanged);
    super.dispose();
  }

  (String?, Uri?) _currentIdentity() => (
    widget.sessionViewModel.session?.email,
    widget.sessionViewModel.lastServerUrl,
  );

  void _onSessionChanged() {
    final identity = _currentIdentity();
    if (identity == _identity) return;
    _identity = identity;
    ref
      ..invalidate(albumListProvider)
      ..invalidate(albumDetailProvider)
      ..invalidate(mediaThumbnailProvider)
      // The upload grid embeds the account-scoped upload history, so it is
      // identity-derived too, even though the photos are local.
      ..invalidate(uploadCandidatesProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
