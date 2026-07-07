import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/providers/portfolio_providers.dart';
import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_theme.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.portfolioId});

  final String portfolioId;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PlatformFile? _pickedFile;
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedAggregator = 'onemoney-aggregator';
  bool _isUploading = false;
  String? _errorMessage;

  final List<Map<String, String>> _aggregators = [
    {'id': 'onemoney-aggregator', 'name': 'OneMoney Aggregator'},
    {'id': 'finvu-aggregator', 'name': 'Finvu (Cookiejar)'},
    {'id': 'anumati-aggregator', 'name': 'Anumati (CAMS)'},
    {'id': 'cams-aggregator', 'name': 'CAMS FinServe'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _pickedFile = null;
        _errorMessage = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(List<String> extensions) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _pickedFile = result.files.first;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _handleUpload() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) {
      setState(() {
        _errorMessage = 'Please select a valid file first.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    final repo = ref.read(portfolioRepositoryProvider);
    final isPdf = _tabController.index == 0;

    final result = isPdf
        ? await repo.importCasPdf(
            widget.portfolioId,
            _pickedFile!.bytes!,
            _pickedFile!.name,
            password: _passwordController.text.isNotEmpty
                ? _passwordController.text
                : null,
          )
        : await repo.importBrokerReport(
            widget.portfolioId,
            _pickedFile!.bytes!,
            _pickedFile!.name,
          );

    setState(() {
      _isUploading = false;
    });

    result.when(
      success: (data) {
        ref.invalidate(portfoliosProvider);
        ref.invalidate(holdingsProvider);
        ref.invalidate(portfolioAnalyticsProvider);
        ref.invalidate(portfolioDoctorProvider);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Import Complete'),
            content: Text(
                'Successfully imported ${data.imported} holdings positions!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  context.pop(); // Go back to portfolio details
                },
                child: const Text('Awesome'),
              ),
            ],
          ),
        );
      },
      failure: (err, _) {
        setState(() {
          _errorMessage = err;
        });
      },
    );
  }

  Future<void> _handleAccountAggregatorLink() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a valid mobile number or VPA identifier.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    final repo = ref.read(portfolioRepositoryProvider);
    final result = await repo.initiateConsent(
      portfolioId: widget.portfolioId,
      phoneNumber: phoneNumber,
      aggregatorId: _selectedAggregator,
    );

    setState(() {
      _isUploading = false;
    });

    result.when(
      success: (consentData) {
        final consentHandle = consentData['consent_handle'] as String;
        final redirectUrl = consentData['redirect_url'] as String;

        _showAARedirectionDialog(consentHandle, redirectUrl);
      },
      failure: (err, _) {
        setState(() {
          _errorMessage = err;
        });
      },
    );
  }

  void _showAARedirectionDialog(String consentHandle, String redirectUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.security, color: Colors.blueAccent),
                SizedBox(width: 10),
                Text('Aggregator Consent Portal'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'WealthAI requests access to view your mutual funds and stocks holdings from your financial accounts.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('• Type: EQUITIES, MUTUAL_FUNDS',
                          style: TextStyle(fontSize: 12)),
                      Text('• Purpose: Wealth Analytics',
                          style: TextStyle(fontSize: 12)),
                      Text('• Validity: 3 Years',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Connecting: $redirectUrl',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _triggerAACallbackAndPolling(consentHandle);
                },
                child: const Text('Approve Consent'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _triggerAACallbackAndPolling(String consentHandle) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AAProgressOverlay(
          consentHandle: consentHandle, portfolioId: widget.portfolioId),
    ).then((result) {
      if (result != null && result is int) {
        ref.invalidate(portfoliosProvider);
        ref.invalidate(holdingsProvider);
        ref.invalidate(portfolioAnalyticsProvider);
        ref.invalidate(portfolioDoctorProvider);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (successCtx) => AlertDialog(
            title: const Text('Link Successful!'),
            content: Text(
                'Successfully linked and imported $result holdings via Account Aggregator!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(successCtx);
                  context.pop(); // Go back to portfolio details
                },
                child: const Text('Proceed'),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAA = _tabController.index == 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Holdings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.picture_as_pdf), text: 'CAS PDF'),
            Tab(icon: Icon(Icons.table_chart), text: 'Broker CSV'),
            Tab(icon: Icon(Icons.sync), text: 'Account Aggregator'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCasTab(theme),
                    _buildBrokerTab(theme),
                    _buildAggregatorTab(theme),
                  ],
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withAlpha(80)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ),
              if (!isAA)
                ElevatedButton(
                  onPressed: _isUploading ? null : _handleUpload,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Upload & Import'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCasTab(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.picture_as_pdf_outlined,
            size: 80, color: theme.colorScheme.primary.withAlpha(128)),
        const SizedBox(height: 16),
        Text('Import CAMS / NSDL CAS PDF', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Select the consolidated account statement PDF downloaded from NSDL, CDSL, or CAMS.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(153)),
        ),
        const SizedBox(height: 24),
        _buildFilePickerArea(theme, ['pdf']),
        const SizedBox(height: 20),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'PDF Password (If encrypted)',
            hintText: 'Usually PAN or email based password',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildBrokerTab(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.table_chart_outlined,
            size: 80, color: theme.colorScheme.primary.withAlpha(128)),
        const SizedBox(height: 16),
        Text('Import Broker CSV/Excel Report',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Select the holdings report CSV file exported from Zerodha Kite, Groww, or other brokers.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(153)),
        ),
        const SizedBox(height: 24),
        _buildFilePickerArea(theme, ['csv', 'xlsx']),
      ],
    ).animate().fadeIn();
  }

  Widget _buildAggregatorTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.sync_alt,
              size: 80, color: theme.colorScheme.primary.withAlpha(128)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Link via Indian Account Aggregator',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Instantly synchronize all your shares, mutual funds, and bank deposits securely using the RBI consent framework.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(153)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Mobile Number or VPA',
              hintText: 'e.g. +919876543210 or username@onemoney',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedAggregator,
            decoration: const InputDecoration(
              labelText: 'Choose Account Aggregator',
              border: OutlineInputBorder(),
            ),
            items: _aggregators.map((agg) {
              return DropdownMenuItem<String>(
                value: agg['id'],
                child: Text(agg['name']!),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedAggregator = val;
                });
              }
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _handleAccountAggregatorLink,
            icon: const Icon(Icons.sync),
            label: const Text('Connect & Import Assets'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildFilePickerArea(ThemeData theme, List<String> extensions) {
    final hasFile = _pickedFile != null;
    return InkWell(
      onTap: () => _pickFile(extensions),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(
              color: theme.colorScheme.primary.withAlpha(128),
              style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.primaryContainer.withAlpha(20),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasFile ? Icons.insert_drive_file : Icons.cloud_upload_outlined,
                color: theme.colorScheme.primary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                hasFile ? _pickedFile!.name : 'Click to select file',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: hasFile ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (hasFile)
                Text(
                  '${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(128)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AAProgressOverlay extends ConsumerStatefulWidget {
  const _AAProgressOverlay({
    required this.consentHandle,
    required this.portfolioId,
  });

  final String consentHandle;
  final String portfolioId;

  @override
  ConsumerState<_AAProgressOverlay> createState() => _AAProgressOverlayState();
}

class _AAProgressOverlayState extends ConsumerState<_AAProgressOverlay> {
  String _statusMessage = 'Connecting to Account Aggregator portal...';
  double _progress = 0.15;
  Timer? _timer;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _triggerCallbackAndStartPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _triggerCallbackAndStartPolling() async {
    final repo = ref.read(portfolioRepositoryProvider);

    // Trigger mock callback
    final dio = ref.read(dioProvider);
    try {
      await dio.get(
        '${ApiConstants.apiPrefix}/portfolios/${widget.portfolioId}/callback',
        queryParameters: {
          'consent_handle': widget.consentHandle,
          'status': 'APPROVED',
        },
      );
    } catch (_) {}

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _ticks++;

      if (_ticks == 1) {
        setState(() {
          _statusMessage = 'Retrieving FIP session keys and Nonces...';
          _progress = 0.45;
        });
      } else if (_ticks == 2) {
        setState(() {
          _statusMessage =
              'Decrypting Equities & Mutual Funds XML materials...';
          _progress = 0.75;
        });
      }

      final statusResult = await repo.getConsentStatus(
        portfolioId: widget.portfolioId,
        consentHandle: widget.consentHandle,
      );

      statusResult.when(
        success: (data) {
          final status = data['status'] as String;
          final count = data['holdings_count'] as int;

          if (status == 'COMPLETED') {
            timer.cancel();
            setState(() {
              _statusMessage = 'Import completed successfully!';
              _progress = 1.0;
            });
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) {
                Navigator.pop(context, count);
              }
            });
          } else if (status == 'FAILED') {
            timer.cancel();
            if (mounted) {
              Navigator.pop(context);
            }
          }
        },
        failure: (_, __) {
          // Continue polling on transient errors
        },
      );

      if (_ticks >= 15) {
        timer.cancel();
        if (mounted) {
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 60,
                width: 60,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).toInt()}% Sync Progress',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
