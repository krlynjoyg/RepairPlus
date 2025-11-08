import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key});

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    const buttonColor = Color(0xFF2E7D71);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Terms & Conditions'),
        backgroundColor: buttonColor,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable terms
            Expanded(
              child: ListView(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: const [
                  Section(
                    title: 'Introduction',
                    children: [
                      Paragraph(
                        'By using RePair+, you agree to these terms and conditions. '
                            'Please read them carefully before proceeding with your account registration.',
                      ),
                    ],
                  ),
                  Section(
                    title: 'Account Registration',
                    children: [
                      Bullet('Users must provide accurate and complete details during registration.'),
                      Bullet('You are responsible for keeping your login credentials safe and secure.'),
                      Bullet('Notify us immediately if you suspect unauthorized access to your account.'),
                    ],
                  ),
                  Section(
                    title: 'Use of the App',
                    children: [
                      Bullet('RePair+ is intended for personal, non-commercial use only.'),
                      Bullet('Users must not misuse the app or provide false repair data.'),
                      Bullet('Respect other users and maintain a positive community environment.'),
                    ],
                  ),
                  Section(
                    title: 'Location Services',
                    children: [
                      Bullet('The app may request location access to show nearby repair shops.'),
                      Bullet('You can disable location services at any time in your device settings.'),
                      Bullet('Location data is used solely to enhance your repair experience.'),
                    ],
                  ),
                  Section(
                    title: 'Data Privacy',
                    children: [
                      Bullet('We store your profile information, repair history, and app activity.'),
                      Bullet('Your data will not be sold or shared with third parties without consent.'),
                      Bullet('We implement security measures to protect your personal information.'),
                    ],
                  ),
                  Section(
                    title: 'Limitations',
                    children: [
                      Bullet('Repair tutorials and shop information are provided "as is".'),
                      Bullet('We are not liable for damages from incorrectly following tutorials.'),
                      Bullet('Always exercise caution and seek professional help when needed.'),
                    ],
                  ),
                  Section(
                    title: 'Termination',
                    children: [
                      Bullet('We may restrict or terminate accounts that violate these terms.'),
                      Bullet('You may delete your account at any time through app settings.'),
                    ],
                  ),
                  Section(
                    title: 'Updates to Terms',
                    children: [
                      Bullet('These terms may be updated periodically to reflect changes.'),
                      Bullet('Users will be notified of significant changes via app notification.'),
                      Bullet('Continued use after updates constitutes acceptance of new terms.'),
                    ],
                  ),
                ],
              ),
            ),

            // Checkbox + Button
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _isChecked,
                        activeColor: buttonColor,
                        onChanged: (val) {
                          setState(() {
                            _isChecked = val ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          "I have read and agree to the Terms & Conditions",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isChecked
                          ? () {
                        Navigator.pop(context, true); // return "agreed"
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        disabledBackgroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        "Continue",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const Section({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF49A37F),
              )),
          const SizedBox(height: 8),
          ...children.map(
                (w) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: w,
            ),
          ),
        ],
      ),
    );
  }
}


class Paragraph extends StatelessWidget {
  final String text;
  const Paragraph(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF333333)),
    );
  }
}


class Bullet extends StatelessWidget {
  final String text;
  const Bullet(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 8, color: Color(0xFF2BB24C)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF333333)),
          ),
        ),
      ],
    );
  }
}
