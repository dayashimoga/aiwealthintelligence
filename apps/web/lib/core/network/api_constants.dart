/// API constants and endpoint definitions.
class ApiConstants {
  ApiConstants._();

  /// Base URL for the API. Override with environment variable.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String apiPrefix = '/api/v1';

  // Auth
  static const String register = '$apiPrefix/auth/register';
  static const String login = '$apiPrefix/auth/login';
  static const String refresh = '$apiPrefix/auth/refresh';
  static const String profile = '$apiPrefix/auth/me';

  // Portfolios
  static const String portfolios = '$apiPrefix/portfolios';
  static String portfolio(String id) => '$portfolios/$id';
  static String portfolioAnalytics(String id) => '$portfolios/$id/analytics';

  // Holdings
  static String holdings(String portfolioId) =>
      '$portfolios/$portfolioId/holdings';
  static String holding(String portfolioId, String holdingId) =>
      '$portfolios/$portfolioId/holdings/$holdingId';
  static String importCasPdf(String portfolioId) =>
      '$portfolios/$portfolioId/import/cas-pdf';
  static String importBrokerReport(String portfolioId) =>
      '$portfolios/$portfolioId/import/broker';

  // AI & Copilot
  static const String aiChat = '$apiPrefix/ai/chat';
  static String aiRecommendation(String portfolioId, String holdingId) =>
      '$apiPrefix/ai/recommendations/$portfolioId/$holdingId';
  
  static const String copilotPrefix = '$apiPrefix/copilot';
  static String copilotBrief(String portfolioId) => '$copilotPrefix/brief/$portfolioId';
  static String copilotDoctor(String portfolioId) => '$copilotPrefix/portfolio-doctor/$portfolioId';
  static String copilotScenario(String portfolioId) => '$copilotPrefix/scenario/$portfolioId';

  // Market
  static const String marketNews = '$apiPrefix/market/news';
  static const String marketSectors = '$apiPrefix/market/sectors';
  static const String marketOverview = '$apiPrefix/market/overview';

  // Health
  static const String health = '$apiPrefix/health';
}
