import 'dart:async';
import 'package:dio/dio.dart';
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
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _pickedFile = null;
        _errorMessage = null;
      });
    });
    // Pre-load email config status
    Future.microtask(_loadEmailConfig);
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
                      Text('â€¢ Type: EQUITIES, MUTUAL_FUNDS',
                          style: TextStyle(fontSize: 12)),
                      Text('â€¢ Purpose: Wealth Analytics',
                          style: TextStyle(fontSize: 12)),
                      Text('â€¢ Validity: 3 Years',
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
    // Tabs 0 (CAS PDF) and 1 (Broker CSV) use the shared upload button.
    // Tabs 2 (AA), 3 (CAMS/KFin), 4 (Email) have their own action buttons.
    final showSharedUploadButton = _tabController.index <= 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Holdings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.picture_as_pdf), text: 'CAS PDF'),
            Tab(icon: Icon(Icons.table_chart), text: 'Broker CSV'),
            Tab(icon: Icon(Icons.sync), text: 'AA Sync'),
            Tab(icon: Icon(Icons.account_balance), text: 'CAMS/KFin'),
            Tab(icon: Icon(Icons.email_outlined), text: 'Email Auto'),
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
                    _buildCamsKFinTab(theme),
                    _buildEmailScanTab(theme),
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
              if (showSharedUploadButton)
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

  // â”€â”€â”€ CAMS / KFin tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  final _camsPasswordCtrl = TextEditingController();
  bool _camsLoading = false;
  String? _camsResult;
  bool _camsError = false;

  Widget _buildCamsKFinTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.account_balance_outlined,
              size: 64, color: theme.colorScheme.primary.withAlpha(180)),
          const SizedBox(height: 12),
          Text('CAMS / KFintech Mutual Fund CAS',
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Upload your Mutual Fund CAS PDF from CAMS or KFintech.\n'
            'Format is auto-detected. Password is usually your PAN (e.g. ABCDE1234F).',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface.withAlpha(153)),
          ),
          const SizedBox(height: 24),
          _buildFilePickerArea(theme, ['pdf']),
          const SizedBox(height: 16),
          TextField(
            controller: _camsPasswordCtrl,
            obscureText: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'PDF Password (PAN in UPPERCASE)',
              hintText: 'e.g. ABCDE1234F',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_camsResult != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_camsError ? Colors.red : Colors.green).withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      (_camsError ? Colors.red : Colors.green).withAlpha(100),
                ),
              ),
              child: Text(
                _camsResult!,
                style: TextStyle(
                  color: _camsError ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed:
                _camsLoading || _pickedFile == null ? null : _handleCamsUpload,
            icon: _camsLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label: Text(_camsLoading ? 'Importingâ€¦' : 'Import Mutual Funds'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ).animate().fadeIn();
  }

  Future<void> _handleCamsUpload() async {
    if (_pickedFile?.bytes == null) return;
    setState(() {
      _camsLoading = true;
      _camsResult = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          _pickedFile!.bytes!,
          filename: _pickedFile!.name,
        ),
        if (_camsPasswordCtrl.text.isNotEmpty)
          'password': _camsPasswordCtrl.text,
      });
      final resp = await dio.post(
        '${ApiConstants.apiPrefix}/portfolios/${widget.portfolioId}/import/cams-kfin',
        data: formData,
      );
      final data = resp.data as Map<String, dynamic>;
      final imported = data['imported'] ?? 0;
      final fmt = (data['format'] ?? 'unknown').toString().toUpperCase();
      final amcs = data['amc_count'] ?? 0;
      if (mounted) {
        setState(() {
          _camsError = false;
          _camsResult =
              'âœ“ Imported $imported schemes ($amcs AMCs) from $fmt statement.';
        });
        ref.invalidate(portfoliosProvider);
        ref.invalidate(holdingsProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _camsError = true;
          _camsResult = 'Import failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _camsLoading = false);
    }
  }

  // â”€â”€â”€ Email auto-scan tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  final _emailPdfPwdCtrl = TextEditingController();
  final _emailSinceDateCtrl = TextEditingController(text: '01-Jan-2024');
  bool _emailLoading = false;
  bool _emailTesting = false;
  String? _emailResult;
  bool _emailError = false;
  Map<String, dynamic>? _emailConfig;
  Map<String, dynamic>? _emailScanSummary;

  Widget _buildEmailScanTab(ThemeData theme) {
    final configured = _emailConfig?['configured'] == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: configured
                    ? Colors.green.withAlpha(120)
                    : Colors.orange.withAlpha(120),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      configured ? Icons.check_circle : Icons.warning_amber,
                      color: configured ? Colors.green : Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text('Email Configuration',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton(
                      onPressed: _loadEmailConfig,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
                if (_emailConfig != null) ...[
                  const SizedBox(height: 8),
                  _emailConfigRow(theme, 'Status',
                      configured ? 'Configured âœ“' : 'Not configured âœ—'),
                  _emailConfigRow(
                      theme, 'Host', _emailConfig!['host'] as String? ?? '-'),
                  _emailConfigRow(
                      theme, 'Email', _emailConfig!['email'] as String? ?? '-'),
                  _emailConfigRow(theme, 'Folder',
                      _emailConfig!['folder'] as String? ?? 'INBOX'),
                ] else
                  const LinearProgressIndicator(),
                if (!configured)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Set EMAIL_IMAP_HOST, EMAIL_ADDRESS, EMAIL_PASSWORD\n'
                      'environment variables to enable email auto-import.',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.orange, fontStyle: FontStyle.italic),
                    ),
                  ),
                if (configured)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: _emailTesting ? null : _testEmailConn,
                      icon: _emailTesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi_tethering, size: 16),
                      label: Text(
                          _emailTesting ? 'Testingâ€¦' : 'Test Connection'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Scan Settings',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailSinceDateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Scan emails since',
                    hintText: 'DD-Mon-YYYY',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailPdfPwdCtrl,
                  obscureText: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'PDF Password (optional PAN override)',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_emailResult != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_emailError ? Colors.red : Colors.green)
                          .withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _emailResult!,
                      style: TextStyle(
                        color: _emailError ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: !configured || _emailLoading ? null : _scanEmail,
                  icon: _emailLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.email_outlined),
                  label: Text(
                      _emailLoading ? 'Scanning mailboxâ€¦' : 'Scan & Import'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          if (_emailScanSummary != null && !_emailError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan Summary',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _emailConfigRow(theme, 'Emails scanned',
                      '${_emailScanSummary!["emails_scanned"] ?? 0}'),
                  _emailConfigRow(theme, 'PDFs found',
                      '${_emailScanSummary!["pdfs_found"] ?? 0}'),
                  _emailConfigRow(theme, 'Imported',
                      '${_emailScanSummary!["imported"] ?? 0}'),
                  _emailConfigRow(theme, 'Skipped',
                      '${_emailScanSummary!["skipped"] ?? 0}'),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _emailConfigRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(130))),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadEmailConfig() async {
    try {
      final dio = ref.read(dioProvider);
      final resp =
          await dio.get('${ApiConstants.apiPrefix}/import/email-config');
      if (mounted) {
        setState(() => _emailConfig = resp.data as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _testEmailConn() async {
    setState(() => _emailTesting = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('${ApiConstants.apiPrefix}/import/email-config/test');
      if (mounted) {
        setState(() {
          _emailError = false;
          _emailResult = 'âœ“ IMAP connection successful.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError = true;
          _emailResult = 'Connection failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _emailTesting = false);
    }
  }

  Future<void> _scanEmail() async {
    setState(() {
      _emailLoading = true;
      _emailResult = null;
      _emailScanSummary = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'since_date': _emailSinceDateCtrl.text,
        if (_emailPdfPwdCtrl.text.isNotEmpty)
          'pdf_password': _emailPdfPwdCtrl.text,
      });
      final resp = await dio.post(
        '${ApiConstants.apiPrefix}/portfolios/${widget.portfolioId}/import/email-scan',
        data: formData,
      );
      final data = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _emailError = false;
          _emailScanSummary = data;
          _emailResult = 'âœ“ Scanned ${data["emails_scanned"]} emails, '
              'imported ${data["imported"]} holdings.';
        });
        ref.invalidate(portfoliosProvider);
        ref.invalidate(holdingsProvider);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError = true;
          _emailResult = 'Scan failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _emailLoading = false);
    }
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
