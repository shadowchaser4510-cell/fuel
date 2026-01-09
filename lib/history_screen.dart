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
  List<ServiceRecord> _serviceRecords = [];
  bool _isLoading = true;
  String _viewMode = 'fuel'; // 'fuel' or 'service'

  @override
  void initState() {
    super.initState();
    _loadData();
    // Listen for changes so the list refreshes automatically when logs are added/updated/deleted
    fuelLogsVersion.addListener(_onExternalChange);
  }

  Widget _buildServiceCard(int index) {
    // display newest-first
    final actualIndex = _serviceRecords.length - 1 - index;
    final record = _serviceRecords[actualIndex];

    return Dismissible(
      key: Key(record.date.toIso8601String()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: kCardColor,
            title: const Text('Delete Record', style: TextStyle(color: kTextColor)),
            content: const Text('Are you sure you want to delete this record?', style: TextStyle(color: kSubTextColor)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: kSubTextColor))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true) {
          try {
            await _apiService.deleteServiceRecord(record);
            if (mounted) {
              setState(() => _serviceRecords.removeAt(actualIndex));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service record deleted'), backgroundColor: Colors.green));
            }
            return true;
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting record: $e'), backgroundColor: Colors.red));
            return false;
          }
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () {
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    backgroundColor: kCardColor,
                    title: Text(DateFormat('EEE, MMM d, yyyy').format(record.date), style: const TextStyle(color: kTextColor)),
                    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Odometer: ${record.odometer} km', style: const TextStyle(color: kSubTextColor)),
                      const SizedBox(height: 8),
                      Text('Cost: ₹${record.cost.toStringAsFixed(2)}', style: const TextStyle(color: kSubTextColor)),
                    ]),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _editServiceRecord(record, actualIndex);
                        },
                        child: const Text('Edit', style: TextStyle(color: kPrimaryColor)),
                      ),
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: kSubTextColor)))
                    ],
                  ));
        },
        child: CustomCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('EEE, MMM d, yyyy').format(record.date), style: const TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Odometer: ${record.odometer} km', style: const TextStyle(color: kSubTextColor)),
              const SizedBox(height: 4),
              Text('Cost: ₹${record.cost.toStringAsFixed(2)}', style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
            ]),
            const Icon(Icons.chevron_right, color: kSubTextColor)
          ]),
        ),
      ),
    );
  }

  void _onExternalChange() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (_viewMode == 'fuel') {
        final logs = await _apiService.getFuelLogs();
        // Sort by odometer ascending and assign index
        logs.sort((a, b) => a.odometer.compareTo(b.odometer));
        for (int i = 0; i < logs.length; i++) {
          logs[i] = FuelLog(
            date: logs[i].date,
            odometer: logs[i].odometer,
            liters: logs[i].liters,
            cost: logs[i].cost,
            isFull: logs[i].isFull,
            tag: logs[i].tag,
            index: i,
          );
        }
        // keep ascending order (oldest first)
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      } else {
        final records = await _apiService.getServiceRecords();
        // Sort by odometer ascending and assign index
        records.sort((a, b) => a.odometer.compareTo(b.odometer));
        for (int i = 0; i < records.length; i++) {
          records[i] = ServiceRecord(
            date: records[i].date,
            odometer: records[i].odometer,
            cost: records[i].cost,
            index: i,
          );
        }
        setState(() {
          _serviceRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading data: $e'),
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
        // index provided by caller is display index (newest-first). Map to actual index
        final actualIndex = _logs.length - 1 - index;
        setState(() => _logs[actualIndex] = result);
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

  Future<void> _editServiceRecord(ServiceRecord record, int index) async {
    final result = await showDialog<ServiceRecord>(
      context: context,
      builder: (ctx) => _EditServiceRecordDialog(record: record),
    );

    if (result != null) {
      try {
        await _apiService.updateServiceRecord(result);
        setState(() => _serviceRecords[index] = result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Service record updated'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error updating record: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _viewMode,
            dropdownColor: kCardColor,
            items: const [
              DropdownMenuItem(value: 'fuel', child: Text('Fuel Log History')),
              DropdownMenuItem(value: 'service', child: Text('Service History')),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _viewMode = val;
              });
              _loadData();
            },
            style: const TextStyle(color: Colors.white, fontSize: 18),
            iconEnabledColor: Colors.white,
          ),
        ),
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
              child: _viewMode == 'fuel'
                  ? (_logs.isEmpty
                      ? const Center(
                          child: Text('No fuel logs yet',
                              style:
                                  TextStyle(color: kSubTextColor, fontSize: 16)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          itemBuilder: (ctx, index) {
                            // display newest-first by mapping index
                            return _buildLogCardIndex(index);
                          },
                        ))
                  : (_serviceRecords.isEmpty
                      ? const Center(
                          child: Text('No service records yet',
                              style:
                                  TextStyle(color: kSubTextColor, fontSize: 16)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _serviceRecords.length,
                          itemBuilder: (ctx, index) {
                            return _buildServiceCard(index);
                          },
                        )),
            ),
    );
  }

  void _showExportOptions() {
    final isService = _viewMode == 'service';
    final title = isService ? 'Export Service Records' : 'Export Fuel Logs';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
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
                _exportLogs('json', '/storage/emulated/0/Download');
              },
            ),
            ListTile(
              title: const Text('Export as CSV',
                  style: TextStyle(color: kTextColor)),
              trailing: const Icon(Icons.file_download, color: kPrimaryColor),
              onTap: () {
                Navigator.pop(ctx);
                _exportLogs('csv', '/storage/emulated/0/Download');
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
      final isService = _viewMode == 'service';
      
      if (isService) {
        if (format == 'json') {
          path = await _apiService.exportServiceRecordsAsJson(customDir: customDir);
        } else {
          path = await _apiService.exportServiceRecordsAsCsv(customDir: customDir);
        }
      } else {
        if (format == 'json') {
          path = await _apiService.exportFuelLogsAsJson(customDir: customDir);
        } else {
          path = await _apiService.exportFuelLogsAsCsv(customDir: customDir);
        }
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
                'CSV format (header required): date,odometer,liters,cost,isFull,tag\nDate format: YYYY-MM-DD\nExample: 2025-12-31,12345,35.7,4300,true,\\"Premium\\"',
                style: TextStyle(color: kSubTextColor)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file, color: Colors.white),
                    label: const Text('Choose CSV File',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
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
      // Set default path to Downloads folder
      String? initialDirectory;
      if (Platform.isAndroid) {
        initialDirectory = '/storage/emulated/0/Download';
      } else if (Platform.isIOS) {
        initialDirectory = null; // iOS handles it differently
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final homeDir = Platform.environment['HOME'] ?? '';
        initialDirectory = '$homeDir/Downloads';
      }
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        initialDirectory: initialDirectory,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final content = String.fromCharCodes(
          file.bytes ?? await File(file.path!).readAsBytes());
      int imported = 0;
      if (_viewMode == 'service') {
        imported = await _apiService.importServiceRecordsFromCsv(content);
      } else {
        imported = await _apiService.importFuelLogsFromCsv(content);
      }
      await _loadData();
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

  Widget _buildLogCardIndex(int displayIndex) {
    // Map display index (newest-first) to actual index (ascending by odometer)
    final actualIndex = _logs.length - 1 - displayIndex;
    final log = _logs[actualIndex];

    // Calculate mileage and rupees/km if possible using odometer-ordered neighbors
    String mileageStr = 'N/A';
    String rupeesPerKmStr = 'N/A';
    if (actualIndex > 0) {
      final prevLog = _logs[actualIndex - 1];
      final distance = log.odometer - prevLog.odometer;
      if (distance > 0 && log.liters > 0) {
        final mileage = distance / log.liters;
        mileageStr = '${mileage.toStringAsFixed(1)} km/L';
        final rpk = log.cost / distance;
        rupeesPerKmStr = '₹${rpk.toStringAsFixed(2)}/km';
      }
    }

    return Dismissible(
      key: Key(log.date.toIso8601String()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
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
            await _apiService.deleteFuelLog(_logs[actualIndex]);
            if (mounted) {
              setState(() => _logs.removeAt(actualIndex));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Log deleted'),
                    backgroundColor: Colors.green),
              );
            }
            return true;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error deleting log: $e'),
                    backgroundColor: Colors.red),
              );
            }
            return false;
          }
        }
        return false;
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
        onTap: () => _editLog(log, displayIndex),
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
                            'Cost: ₹${log.cost.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: kSubTextColor, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mileage: $mileageStr',
                                style: const TextStyle(
                                    color: kPrimaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹/km: $rupeesPerKmStr',
                                style: const TextStyle(
                                    color: kSubTextColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (log.tag != null && log.tag!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Tag: ${log.tag}',
                          style: const TextStyle(
                              color: kSecondaryColor,
                              fontSize: 12,
                              fontStyle: FontStyle.italic),
                        ),
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
  late TextEditingController _tagController;
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
    _tagController = TextEditingController(text: widget.log.tag ?? '');
    _isFullTank = widget.log.isFull;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _odometerController.dispose();
    _litersController.dispose();
    _costController.dispose();
    _tagController.dispose();
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
        tag: _tagController.text.isEmpty ? null : _tagController.text,
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
                labelText: 'Cost (₹)',
                labelStyle: const TextStyle(color: kSubTextColor),
                filled: true,
                fillColor: kBackgroundColor,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagController,
              style: const TextStyle(color: kTextColor),
              decoration: InputDecoration(
                labelText: 'Tag (Optional)',
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

class _EditServiceRecordDialog extends StatefulWidget {
  final ServiceRecord record;

  const _EditServiceRecordDialog({required this.record});

  @override
  State<_EditServiceRecordDialog> createState() =>
      _EditServiceRecordDialogState();
}

class _EditServiceRecordDialogState extends State<_EditServiceRecordDialog> {
  late TextEditingController _dateController;
  late TextEditingController _odometerController;
  late TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(widget.record.date));
    _odometerController =
        TextEditingController(text: widget.record.odometer.toString());
    _costController =
        TextEditingController(text: widget.record.cost.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _dateController.dispose();
    _odometerController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _save() {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(_dateController.text);
      final record = ServiceRecord(
        date: date,
        odometer: int.parse(_odometerController.text),
        cost: double.parse(_costController.text),
        index: widget.record.index,
      );
      Navigator.pop(context, record);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCardColor,
      title: const Text('Edit Service Record', style: TextStyle(color: kTextColor)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _dateController,
            style: const TextStyle(color: kTextColor),
            decoration: InputDecoration(
              labelText: 'Date (yyyy-MM-dd)',
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
            controller: _costController,
            style: const TextStyle(color: kTextColor),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Cost (₹)',
              labelStyle: const TextStyle(color: kSubTextColor),
              filled: true,
              fillColor: kBackgroundColor,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
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
