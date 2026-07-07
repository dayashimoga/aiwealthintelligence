/// API constants and endpoint definitions.
class ApiConstants {
  ApiConstants._();

  /// Base URL for the API. Override with environment variable.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// WebSocket base URL — derived from baseUrl replacing http(s) scheme with ws(s).
  static String get wsBaseUrl => baseUrl.replaceFirst(RegExp(r'^http'), 'ws');

  static const String apiPrefix = '/api/v1';

  // Auth
  static const String register = '$apiPrefix/auth/register';
  static const String login = '$apiPrefix/auth/login';
  static const String refresh = '$apiPrefix/auth/refresh';
  static const String profile = '$apiPrefix/auth/me';
  static const String oauthLogin = '$apiPrefix/auth/oauth-login';
  static const String otpSend = '$apiPrefix/auth/otp/send';
  static const String otpVerify = '$apiPrefix/auth/otp/verify';
  static const String totpSetup = '$apiPrefix/auth/mfa/totp/setup';
  static const String totpEnable = '$apiPrefix/auth/mfa/totp/enable';
  static const String totpDisable = '$apiPrefix/auth/mfa/totp/disable';
  static const String devices = '$apiPrefix/auth/devices';
  static String device(String deviceId) => '$apiPrefix/auth/devices/$deviceId';
  static const String onboardingComplete = '$apiPrefix/auth/onboarding/complete';
  static const String passkeyRegisterOptions = '$apiPrefix/auth/passkeys/register/options';
  static const String passkeyRegisterVerify = '$apiPrefix/auth/passkeys/register/verify';
  static const String passkeyLoginOptions = '$apiPrefix/auth/passkeys/login/options';
  static const String passkeyLoginVerify = '$apiPrefix/auth/passkeys/login/verify';
  static const String deleteAccount = '$apiPrefix/auth/account';
  static const String passwordResetRequest = '$apiPrefix/auth/password-reset/request';
  static const String passwordResetConfirm = '$apiPrefix/auth/password-reset/confirm';

  // Portfolios
  static const String portfolios = '$apiPrefix/portfolios';
  static String portfolio(String id) => '$portfolios/$id';
  static String portfolioAnalytics(String id) => '$portfolios/$id/analytics';

  // Holdings
  static String holdings(String portfolioId) => '$portfolios/$portfolioId/holdings';
  static String holding(String portfolioId, String holdingId) =>
      '$portfolios/$portfolioId/holdings/$holdingId';
  static String importCasPdf(String portfolioId) => '$portfolios/$portfolioId/import/cas-pdf';
  static String importBrokerReport(String portfolioId) => '$portfolios/$portfolioId/import/broker';
  static String initiateConsent(String portfolioId) => '$portfolios/$portfolioId/consent';
  static String getConsentStatus(String portfolioId, String consentHandle) =>
      '$portfolios/$portfolioId/consent/status/$consentHandle';

  // AI & Copilot
  static const String aiChat = '$apiPrefix/ai/chat';
  static String aiRecommendation(String portfolioId, String holdingId) =>
      '$apiPrefix/ai/recommendations/$portfolioId/$holdingId';

  static const String copilotPrefix = '$apiPrefix/copilot';
  static String copilotBrief(String portfolioId) => '$copilotPrefix/brief/$portfolioId';
  static String copilotDoctor(String portfolioId) => '$copilotPrefix/portfolio-doctor/$portfolioId';
  static String copilotScenario(String portfolioId) => '$copilotPrefix/scenario/$portfolioId';
  static String copilotAdvanced(String portfolioId) => '$copilotPrefix/advanced/$portfolioId';
  static String copilotSectorRotation(String portfolioId) =>
      '$copilotPrefix/sector-rotation/$portfolioId';
  static String copilotDividendPlanner(String portfolioId) =>
      '$copilotPrefix/dividend-planner/$portfolioId';
  static String copilotOpportunityRadar(String portfolioId) =>
      '$copilotPrefix/opportunity-radar/$portfolioId';

  // Market
  static const String marketNews = '$apiPrefix/market/news';
  static const String marketSectors = '$apiPrefix/market/sectors';
  static const String marketOverview = '$apiPrefix/market/overview';

  // Notifications
  static const String notifications = '$apiPrefix/notifications';
  static String notificationRead(String id) => '$notifications/$id/read';
  static const String notificationsReadAll = '$notifications/read-all';
  static const String notificationsCount = '$notifications/count';

  // Goals
  static const String goals = '$apiPrefix/goals';
  static String goal(String id) => '$goals/$id';

  // Watchlists
  static const String watchlists = '$apiPrefix/watchlists';
  static String watchlist(String id) => '$watchlists/$id';
  static String watchlistSymbols(String id) => '$watchlists/$id/symbols';
  static String watchlistRemoveSymbol(String id, String symbol) =>
      '$watchlists/$id/symbols/$symbol';
  static String watchlistIntelligence(String id) => '$watchlists/$id/intelligence';

  // Health
  static const String health = '$apiPrefix/health';
}
