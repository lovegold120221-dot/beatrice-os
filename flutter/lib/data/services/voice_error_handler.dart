/// Categorizes voice-channel errors so the UI can present the right recovery
/// hint and decide whether an automatic retry is safe.
///
/// This is a pure-logic utility — no I/O, no dependencies — so it can be unit
/// tested in isolation and reused by both the Live API path and any future
/// streaming voice backend.
enum VoiceErrorCategory {
  /// Temporary connectivity issues that typically clear on retry.
  transientNetwork,

  /// API rate limiting or quota exhaustion.
  quotaExceeded,

  /// Invalid API key or missing permission.
  authFailed,

  /// Connection setup did not complete in time.
  setupTimeout,

  /// Server-side failure reported by the backend.
  serverError,

  /// Any error that does not match a known pattern.
  unknown,
}

/// Pattern-matches raw error strings into a [VoiceErrorCategory] and provides
/// user-facing recovery guidance.
///
/// All members are static; the class is never instantiated.
class VoiceErrorHandler {
  VoiceErrorHandler._();

  /// Inspects [errorText] (case-insensitive) and returns the best-matching
  /// [VoiceErrorCategory].
  ///
  /// The match order is significant: more specific signals (HTTP status codes,
  /// the words "quota" and "rate limit") are tested before generic connection
  /// terms, so a 429 returned alongside a socket error is classified as
  /// [VoiceErrorCategory.quotaExceeded].
  static VoiceErrorCategory categorize(String errorText) {
    final lower = errorText.toLowerCase();

    if (lower.contains('429') ||
        lower.contains('quota') ||
        lower.contains('rate limit')) {
      return VoiceErrorCategory.quotaExceeded;
    }

    if (lower.contains('timeout') || lower.contains('timed out')) {
      return VoiceErrorCategory.setupTimeout;
    }

    if (lower.contains('401') ||
        lower.contains('auth') ||
        lower.contains('permission') ||
        lower.contains('api key')) {
      return VoiceErrorCategory.authFailed;
    }

    if (lower.contains('connect') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('enotfound') ||
        lower.contains('econnrefused')) {
      return VoiceErrorCategory.transientNetwork;
    }

    if (lower.contains('500') ||
        lower.contains('503') ||
        lower.contains('server') ||
        lower.contains('internal')) {
      return VoiceErrorCategory.serverError;
    }

    return VoiceErrorCategory.unknown;
  }

  /// Returns a short, user-facing message for [category].
  ///
  /// Messages are kept neutral and actionable; they never expose the raw error
  /// string or backend details.
  static String userMessage(VoiceErrorCategory category) {
    switch (category) {
      case VoiceErrorCategory.transientNetwork:
        return 'Network unstable — retrying...';
      case VoiceErrorCategory.quotaExceeded:
        return 'API quota reached — please wait 30 seconds';
      case VoiceErrorCategory.authFailed:
        return 'API key invalid — check your settings';
      case VoiceErrorCategory.setupTimeout:
        return 'Connection timed out — retrying...';
      case VoiceErrorCategory.serverError:
        return 'Server error — please try again shortly';
      case VoiceErrorCategory.unknown:
        return 'Connection error — please try again';
    }
  }

  /// Whether the caller may safely retry the failed voice operation without
  /// user intervention.
  ///
  /// Only transient network blips and connection setup timeouts are
  /// auto-retryable; quota, auth, and server errors require either a wait or
  /// a configuration change before another attempt can succeed.
  static bool shouldAutoRetry(VoiceErrorCategory category) {
    return category == VoiceErrorCategory.transientNetwork ||
        category == VoiceErrorCategory.setupTimeout;
  }
}
