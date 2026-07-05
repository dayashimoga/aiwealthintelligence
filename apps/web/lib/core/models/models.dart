/// Domain models for the WealthAI Flutter app.
///
/// These are immutable data classes representing business entities.
/// They mirror the backend API response shapes.

class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.isVerified = false,
    this.mfaEnabled = false,
    this.isOnboarded = false,
    this.avatarUrl = '',
    this.createdAt,
    this.passkeys = const [],
    this.trustedDevices = const [],
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final bool isVerified;
  final bool mfaEnabled;
  final bool isOnboarded;
  final String avatarUrl;
  final DateTime? createdAt;
  final List<Passkey> passkeys;
  final List<Device> trustedDevices;

  factory User.fromJson(Map<String, dynamic> json) {
    final rawPasskeys = json['passkeys'] as List<dynamic>? ?? [];
    final rawDevices = json['trusted_devices'] as List<dynamic>? ?? [];

    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      isVerified: json['is_verified'] as bool? ?? false,
      mfaEnabled: json['mfa_enabled'] as bool? ?? false,
      isOnboarded: json['is_onboarded'] as bool? ?? false,
      avatarUrl: json['avatar_url'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      passkeys: rawPasskeys.map((p) => Passkey.fromJson(p as Map<String, dynamic>)).toList(),
      trustedDevices: rawDevices.map((d) => Device.fromJson(d as Map<String, dynamic>)).toList(),
    );
  }
}

class Portfolio {
  const Portfolio({
    required this.id,
    required this.name,
    this.description = '',
    this.currency = 'INR',
    this.isDefault = false,
    this.importSource = 'manual',
    this.holdingCount = 0,
    this.totalInvested = 0,
    this.totalCurrentValue = 0,
    this.totalGainLoss = 0,
    this.totalGainLossPct = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String currency;
  final bool isDefault;
  final String importSource;
  final int holdingCount;
  final double totalInvested;
  final double totalCurrentValue;
  final double totalGainLoss;
  final double totalGainLossPct;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Portfolio.fromJson(Map<String, dynamic> json) => Portfolio(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    currency: json['currency'] as String? ?? 'INR',
    isDefault: json['is_default'] as bool? ?? false,
    importSource: json['import_source'] as String? ?? 'manual',
    holdingCount: json['holding_count'] as int? ?? 0,
    totalInvested: (json['total_invested'] as num?)?.toDouble() ?? 0,
    totalCurrentValue: (json['total_current_value'] as num?)?.toDouble() ?? 0,
    totalGainLoss: (json['total_gain_loss'] as num?)?.toDouble() ?? 0,
    totalGainLossPct: (json['total_gain_loss_pct'] as num?)?.toDouble() ?? 0,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'currency': currency,
  };
}

class Holding {
  const Holding({
    required this.id,
    required this.portfolioId,
    required this.symbol,
    required this.name,
    this.assetType = 'stock',
    this.exchange = 'NSE',
    this.currency = 'INR',
    this.quantity = 0,
    this.averageBuyPrice = 0,
    this.currentPrice = 0,
    this.investedValue = 0,
    this.currentValue = 0,
    this.gainLoss = 0,
    this.gainLossPct = 0,
    this.sector = '',
    this.industry = '',
    this.country = 'India',
    this.isin = '',
    this.notes = '',
    this.buyDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String portfolioId;
  final String symbol;
  final String name;
  final String assetType;
  final String exchange;
  final String currency;
  final double quantity;
  final double averageBuyPrice;
  final double currentPrice;
  final double investedValue;
  final double currentValue;
  final double gainLoss;
  final double gainLossPct;
  final String sector;
  final String industry;
  final String country;
  final String isin;
  final String notes;
  final DateTime? buyDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Holding.fromJson(Map<String, dynamic> json) => Holding(
    id: json['id'] as String,
    portfolioId: json['portfolio_id'] as String,
    symbol: json['symbol'] as String,
    name: json['name'] as String,
    assetType: json['asset_type'] as String? ?? 'stock',
    exchange: json['exchange'] as String? ?? 'NSE',
    currency: json['currency'] as String? ?? 'INR',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    averageBuyPrice: (json['average_buy_price'] as num?)?.toDouble() ?? 0,
    currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0,
    investedValue: (json['invested_value'] as num?)?.toDouble() ?? 0,
    currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
    gainLoss: (json['gain_loss'] as num?)?.toDouble() ?? 0,
    gainLossPct: (json['gain_loss_pct'] as num?)?.toDouble() ?? 0,
    sector: json['sector'] as String? ?? '',
    industry: json['industry'] as String? ?? '',
    country: json['country'] as String? ?? 'India',
    isin: json['isin'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
    buyDate: json['buy_date'] != null
        ? DateTime.parse(json['buy_date'] as String)
        : null,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'asset_type': assetType,
    'exchange': exchange,
    'quantity': quantity.toString(),
    'average_buy_price': averageBuyPrice.toString(),
    'current_price': currentPrice.toString(),
    'sector': sector,
    'industry': industry,
    'country': country,
    'isin': isin,
    'notes': notes,
  };
}

class PortfolioAnalytics {
  const PortfolioAnalytics({
    required this.portfolioId,
    this.totalInvested = 0,
    this.totalCurrentValue = 0,
    this.totalGainLoss = 0,
    this.totalGainLossPct = 0,
    this.holdingCount = 0,
    this.diversificationScore = 0,
    this.riskScore = 0,
    this.aiHealthScore = 0,
    this.assetAllocation = const {},
    this.sectorAllocation = const {},
    this.countryAllocation = const {},
  });

  final String portfolioId;
  final double totalInvested;
  final double totalCurrentValue;
  final double totalGainLoss;
  final double totalGainLossPct;
  final int holdingCount;
  final double diversificationScore;
  final double riskScore;
  final double aiHealthScore;
  final Map<String, double> assetAllocation;
  final Map<String, double> sectorAllocation;
  final Map<String, double> countryAllocation;

  factory PortfolioAnalytics.fromJson(Map<String, dynamic> json) =>
      PortfolioAnalytics(
        portfolioId: json['portfolio_id'] as String,
        totalInvested: (json['total_invested'] as num?)?.toDouble() ?? 0,
        totalCurrentValue:
            (json['total_current_value'] as num?)?.toDouble() ?? 0,
        totalGainLoss: (json['total_gain_loss'] as num?)?.toDouble() ?? 0,
        totalGainLossPct:
            (json['total_gain_loss_pct'] as num?)?.toDouble() ?? 0,
        holdingCount: json['holding_count'] as int? ?? 0,
        diversificationScore:
            (json['diversification_score'] as num?)?.toDouble() ?? 0,
        riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0,
        aiHealthScore: (json['ai_health_score'] as num?)?.toDouble() ?? 0,
        assetAllocation:
            _parseDoubleMap(json['asset_allocation'] as Map<String, dynamic>?),
        sectorAllocation:
            _parseDoubleMap(json['sector_allocation'] as Map<String, dynamic>?),
        countryAllocation: _parseDoubleMap(
            json['country_allocation'] as Map<String, dynamic>?),
      );

  static Map<String, double> _parseDoubleMap(Map<String, dynamic>? map) {
    if (map == null) return {};
    return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }
}

class AIRecommendation {
  const AIRecommendation({
    required this.id,
    required this.holdingId,
    required this.symbol,
    required this.action,
    this.confidence = 0,
    this.reasoning = '',
    this.evidence = const [],
    this.expectedReturn = 0,
    this.riskLevel = 'moderate',
    this.riskDescription = '',
    this.investmentHorizon = '',
    this.alternativeSuggestions = const [],
    this.explainability = const {},
    this.generatedAt,
  });

  final String id;
  final String holdingId;
  final String symbol;
  final String action;
  final double confidence;
  final String reasoning;
  final List<String> evidence;
  final double expectedReturn;
  final String riskLevel;
  final String riskDescription;
  final String investmentHorizon;
  final List<String> alternativeSuggestions;
  final Map<String, dynamic> explainability;
  final DateTime? generatedAt;

  factory AIRecommendation.fromJson(Map<String, dynamic> json) =>
      AIRecommendation(
        id: json['id'] as String,
        holdingId: json['holding_id'] as String,
        symbol: json['symbol'] as String,
        action: json['action'] as String,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        reasoning: json['reasoning'] as String? ?? '',
        evidence: (json['evidence'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        expectedReturn: (json['expected_return'] as num?)?.toDouble() ?? 0,
        riskLevel: json['risk_level'] as String? ?? 'moderate',
        riskDescription: json['risk_description'] as String? ?? '',
        investmentHorizon: json['investment_horizon'] as String? ?? '',
        alternativeSuggestions:
            (json['alternative_suggestions'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                [],
        explainability:
            json['explainability'] as Map<String, dynamic>? ?? {},
        generatedAt: json['generated_at'] != null
            ? DateTime.parse(json['generated_at'] as String)
            : null,
      );
}

class ChatMessage {
  const ChatMessage({
    required this.message,
    this.suggestions = const [],
    this.referencedHoldings = const [],
    this.confidence = 0,
  });

  final String message;
  final List<String> suggestions;
  final List<String> referencedHoldings;
  final double confidence;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    message: json['message'] as String,
    suggestions: (json['suggestions'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    referencedHoldings: (json['referenced_holdings'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
  );
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
    this.expiresIn = 1800,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
    tokenType: json['token_type'] as String? ?? 'bearer',
    expiresIn: json['expires_in'] as int? ?? 1800,
  );
}

// ============================================================
// Copilot Models
// ============================================================

class DailyBrief {
  const DailyBrief({
    required this.summary,
    required this.marketSentiment,
    this.topGainers = const [],
    this.topLosers = const [],
    this.actionableInsights = const [],
    this.generatedAt,
  });

  final String summary;
  final String marketSentiment;
  final List<Map<String, dynamic>> topGainers;
  final List<Map<String, dynamic>> topLosers;
  final List<String> actionableInsights;
  final DateTime? generatedAt;

  factory DailyBrief.fromJson(Map<String, dynamic> json) => DailyBrief(
        summary: json['summary'] as String? ?? '',
        marketSentiment: json['market_sentiment'] as String? ?? 'neutral',
        topGainers: (json['top_gainers'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        topLosers: (json['top_losers'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
        actionableInsights: (json['actionable_insights'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        generatedAt: json['generated_at'] != null
            ? DateTime.parse(json['generated_at'] as String)
            : null,
      );
}

class ScenarioMetrics {
  const ScenarioMetrics({
    required this.totalValue,
    this.xirr,
    this.diversificationScore = 0.0,
    this.riskScore = 0.0,
  });

  final double totalValue;
  final double? xirr;
  final double diversificationScore;
  final double riskScore;

  factory ScenarioMetrics.fromJson(Map<String, dynamic> json) => ScenarioMetrics(
        totalValue: (json['total_value'] as num?)?.toDouble() ?? 0.0,
        xirr: (json['xirr'] as num?)?.toDouble(),
        diversificationScore:
            (json['diversification_score'] as num?)?.toDouble() ?? 0.0,
        riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
      );
}

class ScenarioSimulation {
  const ScenarioSimulation({
    required this.originalMetrics,
    required this.simulatedMetrics,
    required this.impactSummary,
    this.recommendations = const [],
  });

  final ScenarioMetrics originalMetrics;
  final ScenarioMetrics simulatedMetrics;
  final String impactSummary;
  final List<String> recommendations;

  factory ScenarioSimulation.fromJson(Map<String, dynamic> json) =>
      ScenarioSimulation(
        originalMetrics: ScenarioMetrics.fromJson(
            json['original_metrics'] as Map<String, dynamic>),
        simulatedMetrics: ScenarioMetrics.fromJson(
            json['simulated_metrics'] as Map<String, dynamic>),
        impactSummary: json['impact_summary'] as String? ?? '',
        recommendations: (json['recommendations'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

class PortfolioIssue {
  const PortfolioIssue({
    required this.severity,
    required this.title,
    required this.description,
    required this.recommendation,
  });

  final String severity;
  final String title;
  final String description;
  final String recommendation;

  factory PortfolioIssue.fromJson(Map<String, dynamic> json) => PortfolioIssue(
        severity: json['severity'] as String? ?? 'low',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        recommendation: json['recommendation'] as String? ?? '',
      );
}

class PortfolioDoctor {
  const PortfolioDoctor({
    required this.healthScore,
    this.issues = const [],
    this.diversificationHhi = 0.0,
    this.sectorConcentrationPct = 0.0,
    this.cashDragPct = 0.0,
  });

  final int healthScore;
  final List<PortfolioIssue> issues;
  final double diversificationHhi;
  final double sectorConcentrationPct;
  final double cashDragPct;

  factory PortfolioDoctor.fromJson(Map<String, dynamic> json) => PortfolioDoctor(
        healthScore: json['health_score'] as int? ?? 100,
        issues: (json['issues'] as List<dynamic>?)
                ?.map((e) => PortfolioIssue.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        diversificationHhi:
            (json['diversification_hhi'] as num?)?.toDouble() ?? 0.0,
        sectorConcentrationPct:
            (json['sector_concentration_pct'] as num?)?.toDouble() ?? 0.0,
        cashDragPct: (json['cash_drag_pct'] as num?)?.toDouble() ?? 0.0,
      );
}

class ImportResult {
  const ImportResult({
    required this.imported,
    required this.skipped,
    this.errors = const [],
  });

  final int imported;
  final int skipped;
  final List<String> errors;

  factory ImportResult.fromJson(Map<String, dynamic> json) => ImportResult(
        imported: json['imported'] as int? ?? 0,
        skipped: json['skipped'] as int? ?? 0,
        errors: (json['errors'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

class Device {
  const Device({
    required this.deviceId,
    required this.name,
    required this.registeredAt,
  });

  final String deviceId;
  final String name;
  final DateTime registeredAt;

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        deviceId: json['device_id'] as String,
        name: json['name'] as String,
        registeredAt: DateTime.parse(json['registered_at'] as String),
      );
}

class Passkey {
  const Passkey({
    required this.credentialId,
    required this.createdAt,
  });

  final String credentialId;
  final String createdAt;

  factory Passkey.fromJson(Map<String, dynamic> json) => Passkey(
        credentialId: json['credential_id'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );
}

class MarketNews {
  const MarketNews({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.url,
    required this.sentiment,
    this.relevanceScore = 0.0,
    this.sectors = const [],
    this.symbols = const [],
    this.publishedAt,
  });

  final String id;
  final String title;
  final String summary;
  final String source;
  final String url;
  final String sentiment;
  final double relevanceScore;
  final List<String> sectors;
  final List<String> symbols;
  final DateTime? publishedAt;

  factory MarketNews.fromJson(Map<String, dynamic> json) => MarketNews(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        source: json['source'] as String? ?? '',
        url: json['url'] as String? ?? '',
        sentiment: json['sentiment'] as String? ?? 'neutral',
        relevanceScore: (json['relevance_score'] as num?)?.toDouble() ?? 0.0,
        sectors: (json['sectors'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        symbols: (json['symbols'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        publishedAt: json['published_at'] != null ? DateTime.parse(json['published_at'] as String) : null,
      );
}

class SectorRanking {
  const SectorRanking({
    required this.sector,
    this.performance1d = 0.0,
    this.performance1w = 0.0,
    this.performance1m = 0.0,
    this.performance3m = 0.0,
    this.performance1y = 0.0,
  });

  final String sector;
  final double performance1d;
  final double performance1w;
  final double performance1m;
  final double performance3m;
  final double performance1y;

  factory SectorRanking.fromJson(Map<String, dynamic> json) => SectorRanking(
        sector: json['sector'] as String? ?? '',
        performance1d: (json['performance_1d'] as num?)?.toDouble() ?? 0.0,
        performance1w: (json['performance_1w'] as num?)?.toDouble() ?? 0.0,
        performance1m: (json['performance_1m'] as num?)?.toDouble() ?? 0.0,
        performance3m: (json['performance_3m'] as num?)?.toDouble() ?? 0.0,
        performance1y: (json['performance_1y'] as num?)?.toDouble() ?? 0.0,
      );
}

class MarketOverview {
  const MarketOverview({
    required this.news,
    required this.sectorRankings,
    required this.macroIndicators,
    required this.indexPerformance,
    this.updatedAt,
  });

  final List<MarketNews> news;
  final List<SectorRanking> sectorRankings;
  final Map<String, double> macroIndicators;
  final Map<String, dynamic> indexPerformance;
  final DateTime? updatedAt;

  factory MarketOverview.fromJson(Map<String, dynamic> json) {
    final rawNews = json['news'] as List<dynamic>? ?? [];
    final rawSectors = json['sector_rankings'] as List<dynamic>? ?? [];
    
    final macroMap = <String, double>{};
    if (json['macro_indicators'] != null) {
      (json['macro_indicators'] as Map<String, dynamic>).forEach((k, v) {
        macroMap[k] = (v as num).toDouble();
      });
    }

    return MarketOverview(
      news: rawNews.map((n) => MarketNews.fromJson(n as Map<String, dynamic>)).toList(),
      sectorRankings: rawSectors.map((s) => SectorRanking.fromJson(s as Map<String, dynamic>)).toList(),
      macroIndicators: macroMap,
      indexPerformance: json['index_performance'] as Map<String, dynamic>? ?? {},
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }
}

class StressScenarioResult {
  const StressScenarioResult({
    required this.scenarioName,
    required this.scenarioDescription,
    required this.estimatedNewValue,
    required this.changeValue,
    required this.changePercentage,
    required this.impactLevel,
  });

  final String scenarioName;
  final String scenarioDescription;
  final double estimatedNewValue;
  final double changeValue;
  final double changePercentage;
  final String impactLevel;

  factory StressScenarioResult.fromJson(Map<String, dynamic> json) => StressScenarioResult(
        scenarioName: json['scenario_name'] as String? ?? '',
        scenarioDescription: json['scenario_description'] as String? ?? '',
        estimatedNewValue: (json['estimated_new_value'] as num?)?.toDouble() ?? 0.0,
        changeValue: (json['change_value'] as num?)?.toDouble() ?? 0.0,
        changePercentage: (json['change_percentage'] as num?)?.toDouble() ?? 0.0,
        impactLevel: json['impact_level'] as String? ?? 'neutral',
      );
}

class TaxHarvestingOpportunity {
  const TaxHarvestingOpportunity({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.currentPrice,
    required this.averageBuyPrice,
    required this.unrealizedLoss,
    required this.potentialTaxSavings,
    required this.holdingPeriodDays,
    required this.assetType,
  });

  final String symbol;
  final String name;
  final double quantity;
  final double currentPrice;
  final double averageBuyPrice;
  final double unrealizedLoss;
  final double potentialTaxSavings;
  final int holdingPeriodDays;
  final String assetType;

  factory TaxHarvestingOpportunity.fromJson(Map<String, dynamic> json) => TaxHarvestingOpportunity(
        symbol: json['symbol'] as String? ?? '',
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0.0,
        averageBuyPrice: (json['average_buy_price'] as num?)?.toDouble() ?? 0.0,
        unrealizedLoss: (json['unrealized_loss'] as num?)?.toDouble() ?? 0.0,
        potentialTaxSavings: (json['potential_tax_savings'] as num?)?.toDouble() ?? 0.0,
        holdingPeriodDays: json['holding_period_days'] as int? ?? 0,
        assetType: json['asset_type'] as String? ?? 'stock',
      );
}

class BehavioralBias {
  const BehavioralBias({
    required this.biasName,
    required this.severity,
    required this.description,
    required this.remedy,
  });

  final String biasName;
  final String severity;
  final String description;
  final String remedy;

  factory BehavioralBias.fromJson(Map<String, dynamic> json) => BehavioralBias(
        biasName: json['bias_name'] as String? ?? '',
        severity: json['severity'] as String? ?? 'low',
        description: json['description'] as String? ?? '',
        remedy: json['remedy'] as String? ?? '',
      );
}

class GoalProgress {
  const GoalProgress({
    required this.goalName,
    required this.targetAmount,
    required this.currentAmount,
    required this.progressPercentage,
    required this.status,
  });

  final String goalName;
  final double targetAmount;
  final double currentAmount;
  final double progressPercentage;
  final String status;

  factory GoalProgress.fromJson(Map<String, dynamic> json) => GoalProgress(
        goalName: json['goal_name'] as String? ?? '',
        targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0.0,
        currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0.0,
        progressPercentage: (json['progress_percentage'] as num?)?.toDouble() ?? 0.0,
        status: json['status'] as String? ?? 'on_track',
      );
}

class AdvancedAnalysis {
  const AdvancedAnalysis({
    required this.portfolioId,
    required this.stressTest,
    required this.taxHarvesting,
    required this.totalPotentialTaxSavings,
    required this.behavioralBiases,
    required this.goals,
    required this.calculatedAt,
  });

  final String portfolioId;
  final List<StressScenarioResult> stressTest;
  final List<TaxHarvestingOpportunity> taxHarvesting;
  final double totalPotentialTaxSavings;
  final List<BehavioralBias> behavioralBiases;
  final List<GoalProgress> goals;
  final DateTime? calculatedAt;

  factory AdvancedAnalysis.fromJson(Map<String, dynamic> json) {
    final rawStress = json['stress_test'] as List<dynamic>? ?? [];
    final rawTax = json['tax_harvesting'] as List<dynamic>? ?? [];
    final rawBiases = json['behavioral_biases'] as List<dynamic>? ?? [];
    final rawGoals = json['goals'] as List<dynamic>? ?? [];

    return AdvancedAnalysis(
      portfolioId: json['portfolio_id'] as String? ?? '',
      stressTest: rawStress.map((s) => StressScenarioResult.fromJson(s as Map<String, dynamic>)).toList(),
      taxHarvesting: rawTax.map((t) => TaxHarvestingOpportunity.fromJson(t as Map<String, dynamic>)).toList(),
      totalPotentialTaxSavings: (json['total_potential_tax_savings'] as num?)?.toDouble() ?? 0.0,
      behavioralBiases: rawBiases.map((b) => BehavioralBias.fromJson(b as Map<String, dynamic>)).toList(),
      goals: rawGoals.map((g) => GoalProgress.fromJson(g as Map<String, dynamic>)).toList(),
      calculatedAt: json['calculated_at'] != null ? DateTime.parse(json['calculated_at'] as String) : null,
    );
  }
}


