import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../network/api_constants.dart';
import '../providers/auth_provider.dart';
import '../repositories/repositories.dart';

/// A single price tick received from the WebSocket stream.
class PriceTick {
  const PriceTick({
    required this.symbol,
    required this.price,
    required this.ts,
  });

  final String symbol;
  final double price;
  final DateTime ts;

  factory PriceTick.fromJson(Map<String, dynamic> json) => PriceTick(
        symbol: json['symbol'] as String,
        price: (json['price'] as num).toDouble(),
        ts: DateTime.parse(json['ts'] as String),
      );
}

/// State for the market price stream.
class MarketPriceState {
  const MarketPriceState({
    this.prices = const {},
    this.isConnected = false,
    this.lastUpdated,
    this.error,
  });

  /// symbol → latest PriceTick
  final Map<String, PriceTick> prices;
  final bool isConnected;
  final DateTime? lastUpdated;
  final String? error;

  MarketPriceState copyWith({
    Map<String, PriceTick>? prices,
    bool? isConnected,
    DateTime? lastUpdated,
    String? error,
  }) =>
      MarketPriceState(
        prices: prices ?? this.prices,
        isConnected: isConnected ?? this.isConnected,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        error: error,
      );
}

/// Riverpod StateNotifier managing a live WebSocket connection for market prices.
///
/// Connects to `ws://host/ws/market/prices` with JWT auth, receives price
/// snapshots every `_intervalSeconds` seconds, and reconnects automatically on
/// disconnect (5 s backoff). Supports dynamic symbol subscription via
/// [updateSymbols].
class MarketPriceStreamNotifier extends StateNotifier<MarketPriceState> {
  MarketPriceStreamNotifier(this._ref) : super(const MarketPriceState()) {
    _connect();
  }

  final Ref _ref;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _disposed = false;

  static const _defaultSymbols = ['TCS', 'INFY', 'RELIANCE', 'HDFCBANK', 'ICICIBANK'];
  static const _reconnectDelaySeconds = 5;
  static const _intervalSeconds = 5;

  Future<void> _connect() async {
    if (_disposed) return;

    final authStatus = _ref.read(authStateProvider);
    if (authStatus != AuthStatus.authenticated) {
      state = state.copyWith(
        isConnected: false,
        error: 'Not authenticated',
      );
      return;
    }

    // Read JWT from secure storage
    final token = await _ref.read(authRepositoryProvider).getAccessToken();
    if (token == null) {
      state = state.copyWith(
        isConnected: false,
        error: 'No access token found',
      );
      return;
    }

    try {
      final symbols = _defaultSymbols.join(',');
      final uri = Uri.parse(
        '${ApiConstants.wsBaseUrl}/ws/market/prices'
        '?token=$token'
        '&symbols=$symbols'
        '&interval=$_intervalSeconds',
      );

      _channel = IOWebSocketChannel.connect(uri);
      state = state.copyWith(isConnected: true, error: null);

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      // Ping every 30 s to prevent gateway timeouts
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!_disposed && state.isConnected) {
          _channel?.sink.add(jsonEncode({'action': 'ping'}));
        }
      });
    } catch (e) {
      state = state.copyWith(
        isConnected: false,
        error: 'Connection failed: $e',
      );
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      if (type == 'prices') {
        final data = msg['data'] as Map<String, dynamic>? ?? {};
        final newPrices = Map<String, PriceTick>.from(state.prices);
        for (final entry in data.entries) {
          newPrices[entry.key] = PriceTick.fromJson(entry.value as Map<String, dynamic>);
        }
        state = state.copyWith(
          prices: newPrices,
          lastUpdated: DateTime.now(),
          isConnected: true,
        );
      }
      // pong messages are silently ignored
    } catch (_) {}
  }

  void _onError(Object error) {
    if (_disposed) return;
    state = state.copyWith(isConnected: false, error: 'Stream error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    if (_disposed) return;
    state = state.copyWith(isConnected: false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      const Duration(seconds: _reconnectDelaySeconds),
      _connect,
    );
  }

  /// Dynamically change which symbols are streamed.
  void updateSymbols(List<String> symbols) {
    if (!state.isConnected) return;
    _channel?.sink.add(jsonEncode({
      'action': 'subscribe',
      'symbols': symbols,
    }));
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

/// Global provider for the WebSocket market price stream.
///
/// Watch this in any widget that needs live price data:
/// ```dart
/// final priceState = ref.watch(marketPriceStreamProvider);
/// final tcsPrice = priceState.prices['TCS']?.price;
/// ```
final marketPriceStreamProvider =
    StateNotifierProvider<MarketPriceStreamNotifier, MarketPriceState>(
  (ref) => MarketPriceStreamNotifier(ref),
);
