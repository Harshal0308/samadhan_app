import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:samadhan_app/main.dart';
import 'package:samadhan_app/providers/user_provider.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String? _selectedLanguage;

  static const Map<String, String> _languageToCode = {
    'English': 'en',
    'Hindi': 'hi',
    'Marathi': 'mr',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Choose Language'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLanguageButton(context, 'English'),
            const SizedBox(height: 20),
            _buildLanguageButton(context, 'Hindi'),
            const SizedBox(height: 20),
            _buildLanguageButton(context, 'Marathi'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageButton(BuildContext context, String language) {
    bool isSelected = _selectedLanguage == language;
    return SizedBox(
      width: 200,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: isSelected
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSecondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          final languageCode = _languageToCode[language];
          if (languageCode == null) return; 

          setState(() {
            _selectedLanguage = language;
          });

          Provider.of<UserProvider>(context, listen: false).updateLanguage(languageCode);
          
          Navigator.pop(context);
        },
        child: Text(language),
      ),
    );
  }
}
