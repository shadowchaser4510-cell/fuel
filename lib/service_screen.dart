import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'custom_widgets.dart';
import 'transaction_model.dart';
import 'api_service.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  final ApiService _apiService = ApiService();
  List<ServiceRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final records = await _apiService.getServiceRecords();
      records
          .sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading records: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openAddSheet() async {
    final result = await showModalBottomSheet<ServiceRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: const _AddServiceDialog(),
      ),
    );

    if (result != null) {
      try {
        await _apiService.addServiceRecord(result);
        await _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Service record added'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error adding record: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _editRecord(ServiceRecord record, int index) async {
    final result = await showDialog<ServiceRecord>(
      context: context,
      builder: (ctx) => _EditServiceDialog(record: record),
    );

    if (result != null) {
      try {
        await _apiService.updateServiceRecord(result);
        setState(() => _records[index] = result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Service record updated'),
                backgroundColor: Colors.green),
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
    await _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        title: const Text('Service Records',
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: _records.isEmpty
                  ? const Center(
                      child: Text('No service records yet',
                          style: TextStyle(color: kSubTextColor, fontSize: 16)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _records.length,
                      itemBuilder: (ctx, index) {
                        final record = _records[index];
                        return _buildRecordCard(record, index);
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
            const Text('Export Service Records',
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
                _exportRecords('json', null);
              },
            ),
            ListTile(
              title: const Text('Export as CSV',
                  style: TextStyle(color: kTextColor)),
              trailing: const Icon(Icons.file_download, color: kPrimaryColor),
              onTap: () {
                Navigator.pop(ctx);
                _exportRecords('csv', null);
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
                _exportRecords('json', destinationPath);
              },
            ),
            ListTile(
              title: const Text('CSV', style: TextStyle(color: kTextColor)),
              onTap: () {
                Navigator.pop(ctx);
                _exportRecords('csv', destinationPath);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportRecords(String format, String? customDir) async {
    try {
      String? path;
      if (format == 'json') {
        path =
            await _apiService.exportServiceRecordsAsJson(customDir: customDir);
      } else {
        path =
            await _apiService.exportServiceRecordsAsCsv(customDir: customDir);
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

  Widget _buildRecordCard(ServiceRecord record, int index) {
    return Dismissible(
      key: Key(record.date.toIso8601String()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: kCardColor,
            title: const Text('Delete Service Record',
                style: TextStyle(color: kTextColor)),
            content: const Text(
                'Are you sure you want to delete this service record?',
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
            await _apiService.deleteServiceRecord(_records[index]);
            if (mounted) {
              setState(() => _records.removeAt(index));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Service record deleted'),
                    backgroundColor: Colors.green),
              );
            }
            return true;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error deleting record: $e'),
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
        onTap: () => _editRecord(record, index),
        child: CustomCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEE, MMM d, yyyy').format(record.date),
                      style: const TextStyle(
                          color: kTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Odometer: ${record.odometer} km',
                            style: const TextStyle(
                                color: kSubTextColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cost: Rs ${record.cost.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: kPrimaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
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

class _AddServiceDialog extends StatefulWidget {
  const _AddServiceDialog();

  @override
  State<_AddServiceDialog> createState() => __AddServiceDialogState();
}

class __AddServiceDialogState extends State<_AddServiceDialog> {
  final _dateController = TextEditingController();
  final _odometerController = TextEditingController();
  final _costController = TextEditingController();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: kPrimaryColor,
              onPrimary: Colors.white,
              surface: kCardColor,
              onSurface: kTextColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
      });
    }
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
      final record = ServiceRecord(
        date: _selectedDate,
        odometer: int.parse(_odometerController.text),
        cost: double.parse(_costController.text),
      );
      Navigator.pop(context, record);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Invalid input: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: kBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: kSubTextColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Add Service Record",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kTextColor)),
            const SizedBox(height: 20),
            _buildDateField(),
            const SizedBox(height: 15),
            _buildInputField(
                _odometerController, "Odometer Reading (km)", Icons.speed),
            const SizedBox(height: 15),
            _buildInputField(_costController, "Cost (Rs)", Icons.attach_money),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                child: const Text("Save Record",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: kSubTextColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _dateController.text,
                style: const TextStyle(color: kTextColor, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
      TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: kTextColor),
      keyboardType:
          label.contains("Date") ? TextInputType.text : TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kSubTextColor),
        prefixIcon: Icon(icon, color: kSubTextColor),
        filled: true,
        fillColor: kCardColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }
}

class _EditServiceDialog extends StatefulWidget {
  final ServiceRecord record;

  const _EditServiceDialog({required this.record});

  @override
  State<_EditServiceDialog> createState() => __EditServiceDialogState();
}

class __EditServiceDialogState extends State<_EditServiceDialog> {
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
        TextEditingController(text: widget.record.cost.toStringAsFixed(0));
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
      final record = ServiceRecord(
        date: DateTime.parse(_dateController.text),
        odometer: int.parse(_odometerController.text),
        cost: double.parse(_costController.text),
      );
      Navigator.pop(context, record);
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
      title: const Text('Edit Service Record',
          style: TextStyle(color: kTextColor)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _dateController,
              style: const TextStyle(color: kTextColor),
              decoration: InputDecoration(
                labelText: 'Date (YYYY-MM-DD)',
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
                labelText: 'Cost (Rs)',
                labelStyle: const TextStyle(color: kSubTextColor),
                filled: true,
                fillColor: kBackgroundColor,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
