import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'custom_widgets.dart';
import 'transaction_model.dart';
import 'api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  List<FuelLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    // Listen for changes so the list refreshes automatically when logs are added/updated/deleted
    fuelLogsVersion.addListener(_onExternalChange);
  }

  void _onExternalChange() {
    if (mounted) _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await _apiService.getFuelLogs();
      // Sort by date descending, then by odometer ascending (lower odometer = older on same day)
      logs.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return a.odometer.compareTo(b.odometer);
      });
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading logs: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    fuelLogsVersion.removeListener(_onExternalChange);
    super.dispose();
  }

  Future<void> _editLog(FuelLog log, int index) async {
    final result = await showDialog<FuelLog>(
      context: context,
      builder: (ctx) => _EditLogDialog(log: log),
    );

    if (result != null) {
      try {
        await _apiService.updateFuelLog(result);
        setState(() => _logs[index] = result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Log updated'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error updating log: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        title: const Text('Fuel Log History',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _showExportOptions,
          ),
          IconButton(
            icon: const Icon(Icons.upload, color: Colors.white),
            onPressed: _showImportOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: _logs.isEmpty
                  ? const Center(
                      child: Text('No fuel logs yet',
                          style: TextStyle(color: kSubTextColor, fontSize: 16)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length,
                      itemBuilder: (ctx, index) {
                        final log = _logs[index];
                        return _buildLogCard(log, index);
                      },
                    ),
            ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Export Fuel Logs',
                style: TextStyle(
                    color: kTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Export as JSON',
                  style: TextStyle(color: kTextColor)),
              trailing: const Icon(Icons.file_download, color: kPrimaryColor),
              onTap: () {
                Navigator.pop(ctx);
                _exportLogs('json', null);
              },
            ),
            ListTile(
              title: const Text('Export as CSV',
                  style: TextStyle(color: kTextColor)),
              trailing: const Icon(Icons.file_download, color: kPrimaryColor),
              onTap: () {
                Navigator.pop(ctx);
                _exportLogs('csv', null);
              },
            ),
            const Divider(color: kSubTextColor),
            const Text('Or choose a destination folder:',
                style: TextStyle(color: kSubTextColor, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.folder),
                    label: const Text('Downloads'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showFormatAndExport('/storage/emulated/0/Download');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFormatAndExport(String destinationPath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('Select Format', style: TextStyle(color: kTextColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('JSON', style: TextStyle(color: kTextColor)),
              onTap: () {
                Navigator.pop(ctx);
                _exportLogs('json', destinationPath);
              },
            ),
            ListTile(
              title: const Text('CSV', style: TextStyle(color: kTextColor)),
              onTap: () {
                Navigator.pop(ctx);
                _exportLogs('csv', destinationPath);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportLogs(String format, String? customDir) async {
    try {
      String? path;
      if (format == 'json') {
        path = await _apiService.exportFuelLogsAsJson(customDir: customDir);
      } else {
        path = await _apiService.exportFuelLogsAsCsv(customDir: customDir);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to:\n$path'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Import Fuel Logs (CSV)',
                style: TextStyle(
                    color: kTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
                'CSV format (header required): date,odometer,liters,cost,isFull\nDate format: YYYY-MM-DD\nExample: 2025-12-31,12345,35.7,4300,true',
                style: TextStyle(color: kSubTextColor)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Choose CSV File'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _importFromCsv();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final content = String.fromCharCodes(
          file.bytes ?? await File(file.path!).readAsBytes());
      final imported = await _apiService.importFuelLogsFromCsv(content);
      await _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Imported $imported rows'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildLogCard(FuelLog log, int index) {
    // Calculate mileage if possible
    String mileageStr = 'N/A';
    if (index < _logs.length - 1) {
      final prevLog =
          _logs[index + 1]; // Next item in descending order = previous in time
      final distance = log.odometer - prevLog.odometer;
      if (distance > 0 && log.liters > 0) {
        final mileage = distance / log.liters;
        mileageStr = '${mileage.toStringAsFixed(1)} km/L';
      }
    }

    return Dismissible(
      key: Key(log.date.toIso8601String()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        // Show confirmation dialog before dismissing
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: kCardColor,
            title:
                const Text('Delete Log', style: TextStyle(color: kTextColor)),
            content: const Text('Are you sure you want to delete this log?',
                style: TextStyle(color: kSubTextColor)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: kSubTextColor)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          try {
            await _apiService.deleteFuelLog(_logs[index]);
            if (mounted) {
              setState(() => _logs.removeAt(index));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Log deleted'),
                    backgroundColor: Colors.green),
              );
            }
            return true; // Allow dismissal
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error deleting log: $e'),
                    backgroundColor: Colors.red),
              );
            }
            return false; // Don't dismiss on error
          }
        }
        return false; // Don't dismiss if not confirmed
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => _editLog(log, index),
        child: CustomCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEE, MMM d, yyyy – h:mm a').format(log.date),
                      style: const TextStyle(
                          color: kTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Odometer: ${log.odometer} km',
                            style: const TextStyle(
                                color: kSubTextColor, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Liters: ${log.liters.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: kSubTextColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Cost: \$${log.cost.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: kSubTextColor, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mileage: $mileageStr',
                            style: const TextStyle(
                                color: kPrimaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (log.isFull)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Full Tank',
                            style: TextStyle(
                                color: kPrimaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.edit, color: kPrimaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditLogDialog extends StatefulWidget {
  final FuelLog log;

  const _EditLogDialog({required this.log});

  @override
  State<_EditLogDialog> createState() => __EditLogDialogState();
}

class __EditLogDialogState extends State<_EditLogDialog> {
  late TextEditingController _dateController;
  late TextEditingController _odometerController;
  late TextEditingController _litersController;
  late TextEditingController _costController;
  late bool _isFullTank;

  @override
  void initState() {
    super.initState();
    _dateController =
        TextEditingController(text: widget.log.date.toIso8601String());
    _odometerController =
        TextEditingController(text: widget.log.odometer.toString());
    _litersController =
        TextEditingController(text: widget.log.liters.toString());
    _costController = TextEditingController(text: widget.log.cost.toString());
    _isFullTank = widget.log.isFull;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _odometerController.dispose();
    _litersController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _save() {
    try {
      final updatedLog = FuelLog(
        date: DateTime.parse(_dateController.text),
        odometer: int.parse(_odometerController.text),
        liters: double.parse(_litersController.text),
        cost: double.parse(_costController.text),
        isFull: _isFullTank,
      );
      Navigator.pop(context, updatedLog);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Invalid input: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCardColor,
      title: const Text('Edit Fuel Log', style: TextStyle(color: kTextColor)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dateController,
              style: const TextStyle(color: kTextColor),
              decoration: InputDecoration(
                labelText: 'Date & Time (ISO format)',
                labelStyle: const TextStyle(color: kSubTextColor),
                filled: true,
                fillColor: kBackgroundColor,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _odometerController,
              style: const TextStyle(color: kTextColor),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Odometer (km)',
                labelStyle: const TextStyle(color: kSubTextColor),
                filled: true,
                fillColor: kBackgroundColor,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _litersController,
              style: const TextStyle(color: kTextColor),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Liters',
                labelStyle: const TextStyle(color: kSubTextColor),
                filled: true,
                fillColor: kBackgroundColor,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costController,
              style: const TextStyle(color: kTextColor),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cost (\$)',
                labelStyle: const TextStyle(color: kSubTextColor),
                filled: true,
                fillColor: kBackgroundColor,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title:
                  const Text('Full Tank?', style: TextStyle(color: kTextColor)),
              value: _isFullTank,
              onChanged: (val) => setState(() => _isFullTank = val ?? false),
              activeColor: kPrimaryColor,
              checkColor: Colors.white,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: kSubTextColor)),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Save', style: TextStyle(color: kPrimaryColor)),
        ),
      ],
    );
  }
}
