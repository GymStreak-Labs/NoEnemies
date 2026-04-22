/// Single source of truth for the hosted legal documents.
///
/// These URLs point to the AppStore Copilot-hosted Privacy Policy and Terms
/// of Use for NoEnemies. Referenced by:
/// - The paywall footer (tappable "Terms" / "Privacy" links).
/// - The You-tab settings sheet (Privacy Policy / Terms of Use rows).
/// - The app description footer on the App Store / Play Store listings.
///
/// Slug `8inqwejl` is shared across the iOS + Android Copilot projects
/// (legal-doc ownership is linked in Copilot), so a single edit via
/// `update_legal_document` + `push_legal_to_appstore` updates all surfaces.
class LegalUrls {
  const LegalUrls._();

  static const String privacyPolicy =
      'https://appstorecopilot.com/legal/8inqwejl/privacy';

  static const String termsOfUse =
      'https://appstorecopilot.com/legal/8inqwejl/terms';
}
