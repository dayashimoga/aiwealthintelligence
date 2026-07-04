import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Screen for adding a new holding to a portfolio.
class AddHoldingScreen extends StatefulWidget {
  const AddHoldingScreen({super.key, required this.portfolioId});

  final String portfolioId;

  @override
  State<AddHoldingScreen> createState() => _AddHoldingScreenState();
}

class _AddHoldingScreenState extends State<AddHoldingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symbolController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _sectorController = TextEditingController();
  String _assetType = 'stock';
  String _exchange = 'NSE';
  bool _isLoading = false;

  final _assetTypes = [
    'stock', 'mutual_fund', 'etf', 'bond', 'gold',
    'crypto', 'real_estate', 'fixed_deposit', 'ppf', 'nps',
  ];

  final _exchanges = ['NSE', 'BSE', 'NYSE', 'NASDAQ'];

  @override
  void dispose() {
    _symbolController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _sectorController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_symbolController.text.toUpperCase()} added to portfolio'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Holding')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Asset Type & Exchange
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _assetType,
                          decoration: const InputDecoration(labelText: 'Asset Type'),
                          items: _assetTypes.map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.replaceAll('_', ' ').toUpperCase()),
                          )).toList(),
                          onChanged: (v) => setState(() => _assetType = v!),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMd),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _exchange,
                          decoration: const InputDecoration(labelText: 'Exchange'),
                          items: _exchanges.map((e) => DropdownMenuItem(
                            value: e, child: Text(e),
                          )).toList(),
                          onChanged: (v) => setState(() => _exchange = v!),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: AppTheme.spacingMd),

                  // Symbol & Name
                  TextFormField(
                    controller: _symbolController,
                    decoration: const InputDecoration(
                      labelText: 'Symbol / Ticker',
                      hintText: 'e.g., RELIANCE, TCS',
                      prefixIcon: Icon(Icons.search),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => v == null || v.isEmpty ? 'Symbol is required' : null,
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: AppTheme.spacingMd),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Company / Fund Name',
                      hintText: 'e.g., Reliance Industries Ltd',
                      prefixIcon: Icon(Icons.business),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: AppTheme.spacingMd),

                  // Quantity & Price
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            hintText: '0',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null || double.parse(v) <= 0) {
                              return 'Invalid quantity';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMd),
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Avg. Buy Price (₹)',
                            hintText: '0.00',
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (double.tryParse(v) == null) return 'Invalid price';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: AppTheme.spacingMd),

                  TextFormField(
                    controller: _sectorController,
                    decoration: const InputDecoration(
                      labelText: 'Sector (optional)',
                      hintText: 'e.g., Information Technology',
                      prefixIcon: Icon(Icons.category),
                    ),
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: AppTheme.spacingXl),

                  // Estimated Value Preview
                  Builder(builder: (context) {
                    final qty = double.tryParse(_quantityController.text) ?? 0;
                    final price = double.tryParse(_priceController.text) ?? 0;
                    final total = qty * price;
                    if (total > 0) {
                      return Container(
                        padding: const EdgeInsets.all(AppTheme.spacingMd),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withAlpha(51),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Estimated Investment', style: theme.textTheme.bodyMedium),
                            Text('₹${total.toStringAsFixed(2)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                )),
                          ],
                        ),
                      ).animate().fadeIn();
                    }
                    return const SizedBox.shrink();
                  }),

                  const SizedBox(height: AppTheme.spacingLg),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleSubmit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add),
                      label: Text(_isLoading ? 'Adding...' : 'Add Holding'),
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
