/// Release configuration that lives outside the code's logic: public URLs and
/// contact addresses shown to users and required by the app stores.
///
/// Every value can be overridden at build time with --dart-define, so a
/// release can be built without editing source:
///
///   flutter build appbundle \
///     --dart-define=PRIVACY_POLICY_URL=https://example.com/privacy \
///     --dart-define=TERMS_URL=https://example.com/terms \
///     --dart-define=SUPPORT_EMAIL=support@example.com
///
/// See docs/RELEASE.md for the full list of placeholders to fill in.
abstract final class AppConfig {
  /// Public privacy policy page. Both stores require one; when empty, the app
  /// falls back to the in-app copy of the policy.
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');

  /// Public terms of service page. Falls back to the in-app copy when empty.
  static const termsUrl = String.fromEnvironment('TERMS_URL');

  /// Where users are told to write for help, privacy requests and legal notices.
  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@communiq.app',
  );
}
