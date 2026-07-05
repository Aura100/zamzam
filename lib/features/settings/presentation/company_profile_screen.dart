import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/app_layout.dart';
import 'settings_providers.dart';

class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  ConsumerState<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await ref.read(companySettingsProvider.future);
    setState(() {
      _nameCtrl.text = data['company_name'] ?? '';
      _phoneCtrl.text = data['company_phone'] ?? '';
      _addressCtrl.text = data['company_address'] ?? '';
    });
  }

  Future<void> _saveData() async {
    final db = ref.read(databaseProvider);
    
    Future<void> saveKey(String k, String v) async {
      await db.into(db.companySettings).insertOnConflictUpdate(
        CompanySettingsCompanion(key: drift.Value(k), value: drift.Value(v))
      );
    }

    await saveKey('company_name', _nameCtrl.text.trim());
    await saveKey('company_phone', _phoneCtrl.text.trim());
    await saveKey('company_address', _addressCtrl.text.trim());

    ref.invalidate(companySettingsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات بنجاح'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: 'إعدادات الشركة والفواتير',
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('بيانات الشركة الأساسية (تظهر في ترويسة الفواتير)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الشركة',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _saveData,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ التعديلات'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
