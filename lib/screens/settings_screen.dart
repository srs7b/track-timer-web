import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/seed_data_service.dart';
import '../theme/style_constants.dart';
import '../widgets/velocity_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final apiKey = await _db.getSetting('gemini_api_key');
    if (mounted) {
      setState(() {
        _apiKeyController.text = apiKey ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveApiKey() async {
    await _db.saveSetting('gemini_api_key', _apiKeyController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API KEY SAVED', style: VelocityTextStyles.technical.copyWith(fontSize: 10, color: VelocityColors.black)),
          backgroundColor: VelocityColors.primary,
        ),
      );
    }
  }

  Future<void> _clearData() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VelocityColors.surfaceLight,
        title: Text('CLEAR ALL DATA?', style: VelocityTextStyles.technical.copyWith(color: Colors.redAccent)),
        content: Text('This will delete all runs and athletes. This action cannot be undone.', style: VelocityTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textDim))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('DELETE', style: VelocityTextStyles.technical.copyWith(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      await _db.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('DATABASE CLEARED')));
      }
    }
  }

  Future<void> _reseedData() async {
    setState(() => _isLoading = true);
    await _db.clearAllData();
    await SeedDataService.seedIfNecessary();
    await _loadSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PROTOTYPE DATA RESEEDED')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VelocityColors.black,
      appBar: AppBar(
        title: Text('SETTINGS', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.textBody, letterSpacing: 2)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: VelocityColors.primary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('AI COACH CONFIGURATION'),
                VelocityCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GEMINI API KEY', style: VelocityTextStyles.dimBody.copyWith(fontSize: 9, letterSpacing: 1)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiKeyController,
                        style: VelocityTextStyles.body,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Enter API Key...',
                          hintStyle: VelocityTextStyles.dimBody,
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: VelocityColors.textDim)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: VelocityColors.primary)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _saveApiKey,
                          child: Text('SAVE KEY', style: VelocityTextStyles.technical.copyWith(color: VelocityColors.primary, fontSize: 10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                _buildSectionTitle('DATA MANAGEMENT'),
                VelocityCard(
                  child: Column(
                    children: [
                      _buildActionRow(
                        'CLEAR DATABASE', 
                        'Wipe all performance data and athletes.',
                        onTap: _clearData,
                        isDestructive: true,
                      ),
                      const Divider(color: VelocityColors.textDim, height: 32, thickness: 0.1),
                      _buildActionRow(
                        'RESEED PROTOTYPE', 
                        'Reset database and inject new sample data.',
                        onTap: _reseedData,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                Center(
                  child: Column(
                    children: [
                      Text('TRACK.TIME v1.0.4', style: VelocityTextStyles.technical.copyWith(fontSize: 9, color: VelocityColors.textDim)),
                      const SizedBox(height: 4),
                      Text('CONNECTED TO LOCAL STORAGE', style: VelocityTextStyles.dimBody.copyWith(fontSize: 8)),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: VelocityTextStyles.technical.copyWith(fontSize: 10, letterSpacing: 2, color: VelocityColors.textDim)),
    );
  }

  Widget _buildActionRow(String title, String subtitle, {required VoidCallback onTap, bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: VelocityTextStyles.body.copyWith(color: isDestructive ? Colors.redAccent : VelocityColors.textBody, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: VelocityTextStyles.dimBody.copyWith(fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: VelocityColors.textDim, size: 20),
          ],
        ),
      ),
    );
  }
}
