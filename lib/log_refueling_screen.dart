import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'transaction_model.dart';
import 'custom_widgets.dart';

class LogRefuelingScreen extends StatefulWidget {
  const LogRefuelingScreen({super.key});

  @override
  State<LogRefuelingScreen> createState() => _LogRefuelingScreenState();
}

class _LogRefuelingScreenState extends State<LogRefuelingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometerController = TextEditingController();
  final _litersController = TextEditingController();
  final _costController = TextEditingController();
  final _dateController = TextEditingController();
  late DateTime _selectedDate;
  bool _isFullTank = true;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _litersController.dispose();
    _costController.dispose();
    _dateController.dispose();
    super.dispose();
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
        _dateController.text = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
      });
    }
  }

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final newLog = FuelLog(
          date: _selectedDate,
          odometer: int.parse(_odometerController.text),
          liters: double.parse(_litersController.text),
          cost: double.parse(_costController.text),
          isFull: _isFullTank,
        );

        final success = await _apiService.addFuelLog(newLog);

        if (mounted) {
          Navigator.pop(context, success); // Return success status
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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
        child: Form(
          key: _formKey,
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
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              const Text("Log new refueling",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kTextColor)),
              const SizedBox(height: 20),
              _buildDateField(),
              const SizedBox(height: 15),
              _buildInputField(
                  _odometerController, "Odometer Reading", Icons.speed),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                      child: _buildInputField(
                          _litersController, "Liters", Icons.local_gas_station)),
                  const SizedBox(width: 15),
                  Expanded(
                      child: _buildInputField(
                          _costController, "Total Cost", Icons.attach_money)),
                ],
              ),
              const SizedBox(height: 15),
              SwitchListTile(
                title:
                    const Text("Full Tank?", style: TextStyle(color: kTextColor)),
                value: _isFullTank,
                onChanged: (val) => setState(() => _isFullTank = val),
                activeColor: kPrimaryColor,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Entry",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
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
      keyboardType: TextInputType.number,
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
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter a value';
        if (double.tryParse(value) == null) return 'Enter a valid number';
        return null;
      },
    );
  }
}
