import 'url_strategy_stub.dart'
    if (dart.library.html) 'url_strategy_web.dart';

/// Enables clean `/path` URLs on Flutter Web.
///
/// On non-web platforms this is a no-op.
void configureUrlStrategy() => configureUrlStrategyImpl();

