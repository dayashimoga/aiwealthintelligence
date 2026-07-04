import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/portfolio_providers.dart';
import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.portfolioId});

  final String portfolioId;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PlatformFile? _pickedFile;
  final _passwordController = TextEditingController();
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _passwordController.dispose();
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
            password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
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
            content: Text('Successfully imported ${data.imported} holdings positions!'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Holdings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.picture_as_pdf), text: 'CAS PDF Statement'),
            Tab(icon: Icon(Icons.table_chart), text: 'Broker CSV Report'),
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
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
        Icon(Icons.picture_as_pdf_outlined, size: 80, color: theme.colorScheme.primary.withAlpha(128)),
        const SizedBox(height: 16),
        Text('Import CAMS / NSDL CAS PDF', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Select the consolidated account statement PDF downloaded from NSDL, CDSL, or CAMS.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(153)),
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
        Icon(Icons.table_chart_outlined, size: 80, color: theme.colorScheme.primary.withAlpha(128)),
        const SizedBox(height: 16),
        Text('Import Broker CSV/Excel Report', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Select the holdings report CSV file exported from Zerodha Kite, Groww, or other brokers.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(153)),
        ),
        const SizedBox(height: 24),
        _buildFilePickerArea(theme, ['csv', 'xlsx']),
      ],
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
          border: Border.all(color: theme.colorScheme.primary.withAlpha(128), style: BorderStyle.solid),
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
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(128)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
