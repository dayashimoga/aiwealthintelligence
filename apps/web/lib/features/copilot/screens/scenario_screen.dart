import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/models.dart';
import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class ScenarioScreen extends ConsumerStatefulWidget {
  const ScenarioScreen({super.key, required this.portfolioId});

  final String portfolioId;

  @override
  ConsumerState<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends ConsumerState<ScenarioScreen> {
  final _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  final List<Map<String, dynamic>> _simulatedActions = [];
  final _symbolController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedAction = 'buy';
  bool _isSimulating = false;
  ScenarioSimulation? _simulationResult;
  String? _errorMessage;

  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addAction() {
    final symbol = _symbolController.text.toUpperCase().trim();
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    if (symbol.isEmpty || qty <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields with valid numbers.')),
      );
      return;
    }

    setState(() {
      _simulatedActions.add({
        'symbol': symbol,
        'action': _selectedAction,
        'quantity': qty,
        'price': price,
      });
      _symbolController.clear();
      _quantityController.clear();
      _priceController.clear();
    });
  }

  void _removeAction(int index) {
    setState(() {
      _simulatedActions.removeAt(index);
    });
  }

  Future<void> _runSimulation() async {
    if (_simulatedActions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one trade to simulate.')),
      );
      return;
    }

    setState(() {
      _isSimulating = true;
      _simulationResult = null;
      _errorMessage = null;
    });

    final repo = ref.read(aiRepositoryProvider);
    final result = await repo.simulateScenario(widget.portfolioId, _simulatedActions);

    setState(() {
      _isSimulating = false;
    });

    result.when(
      success: (data) {
        setState(() {
          _simulationResult = data;
        });
      },
      failure: (err, _) {
        setState(() {
          _errorMessage = err;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scenario Simulator'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Transaction Form Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Trade to Simulate', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _symbolController,
                              decoration: const InputDecoration(labelText: 'Ticker (e.g. TCS)'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _selectedAction,
                            items: const [
                              DropdownMenuItem(value: 'buy', child: Text('BUY')),
                              DropdownMenuItem(value: 'sell', child: Text('SELL')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedAction = val;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _quantityController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Quantity'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Price (₹)'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _addAction,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // 2. Added actions list
              if (_simulatedActions.isNotEmpty) ...[
                Text('Proposed Trades:', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _simulatedActions.length,
                    itemBuilder: (context, index) {
                      final item = _simulatedActions[index];
                      final isBuy = item['action'] == 'buy';
                      return Card(
                        color: isBuy ? Colors.green.withAlpha(20) : Colors.red.withAlpha(20),
                        margin: const EdgeInsets.only(right: 8, bottom: 4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${item['action'].toString().toUpperCase()} ${item['symbol']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    '${item['quantity']} units @ ₹${item['price']}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => _removeAction(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.spacingMd),

              // 3. Action Buttons & Simulation result panel
              ElevatedButton.icon(
                onPressed: _isSimulating ? null : _runSimulation,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Simulate Scenario impact'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              Expanded(
                child: _isSimulating
                    ? const Center(child: CircularProgressIndicator())
                    : (_errorMessage != null
                        ? Center(child: Text('Error simulating: $_errorMessage'))
                        : (_simulationResult == null
                            ? const Center(child: Text('Add proposed trades and tap simulate to see metrics changes.'))
                            : ListView(
                                children: [
                                  _buildComparisonTable(theme),
                                  const SizedBox(height: 16),
                                  _buildImpactTextCard(theme),
                                ],
                              ))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonTable(ThemeData theme) {
    final orig = _simulationResult!.originalMetrics;
    final sim = _simulationResult!.simulatedMetrics;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Metrics Comparison', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  children: [
                    const Padding(padding: EdgeInsets.all(4), child: Text('Metric', style: TextStyle(fontWeight: FontWeight.bold))),
                    const Padding(padding: EdgeInsets.all(4), child: Text('Original', style: TextStyle(fontWeight: FontWeight.bold))),
                    const Padding(padding: EdgeInsets.all(4), child: Text('Simulated', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(padding: EdgeInsets.all(4), child: Text('Portfolio Value')),
                    Padding(padding: const EdgeInsets.all(4), child: Text(_currencyFormatter.format(orig.totalValue))),
                    Padding(padding: const EdgeInsets.all(4), child: Text(_currencyFormatter.format(sim.totalValue), style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(padding: EdgeInsets.all(4), child: Text('Diversification')),
                    Padding(padding: const EdgeInsets.all(4), child: Text('${orig.diversificationScore.toStringAsFixed(0)}/100')),
                    Padding(padding: const EdgeInsets.all(4), child: Text('${sim.diversificationScore.toStringAsFixed(0)}/100', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                TableRow(
                  children: [
                    const Padding(padding: EdgeInsets.all(4), child: Text('Risk Index')),
                    Padding(padding: const EdgeInsets.all(4), child: Text('${orig.riskScore.toStringAsFixed(1)}/5.0')),
                    Padding(padding: const EdgeInsets.all(4), child: Text('${sim.riskScore.toStringAsFixed(1)}/5.0', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactTextCard(ThemeData theme) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text('AI Impact Assessment', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _simulationResult!.impactSummary,
            style: const TextStyle(height: 1.4, fontSize: 13),
          ),
          if (_simulationResult!.recommendations.isNotEmpty) ...[
            const Divider(height: 24),
            Text('Recommendations:', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._simulationResult!.recommendations.map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(rec, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
