import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:crypto/crypto.dart';

void main() {
  runApp(const BlackVaultWallet());
}

class BlackVaultWallet extends StatelessWidget {
  const BlackVaultWallet({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlackVault Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.deepPurple,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? scannedNote;
  Map<String, dynamic>? noteData;
  final storage = const FlutterSecureStorage();
  bool showScanner = false;

  @override
  Widget build(BuildContext context) {
    final hasNote = noteData != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlackVault Wallet'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple[900],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "Confidential value.\nOpen-world mobility.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ),
          Expanded(
            child: hasNote
                ? _buildNoteView()
                : (showScanner ? _buildScannerView() : _buildWelcomeView()),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple[900],
            child: const Text(
              "Non-custodial. Bearer. Censorship-resistant.\nYou control everything.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: hasNote
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  heroTag: "scan",
                  onPressed: () => setState(() => showScanner = true),
                  label: const Text("Scan Note"),
                  icon: const Icon(Icons.qr_code_scanner),
                  backgroundColor: Colors.deepPurple[700],
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: "paste",
                  onPressed: () => _showPasteDialog(context),
                  label: const Text("Paste Note"),
                  icon: const Icon(Icons.content_paste),
                  backgroundColor: Colors.deepPurple[600],
                ),
              ],
            ),
    );
  }

  Widget _buildWelcomeView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_open, size: 100, color: Colors.white30),
          SizedBox(height: 30),
          Text(
            "Ready to receive a private note",
            style: TextStyle(fontSize: 20, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              final String? code = barcode.rawValue;
              if (code != null && code.contains('"version":')) {
                try {
                  final data = jsonDecode(code) as Map<String, dynamic>;
                  if (data['version'] == 5 || data['version'] == "v5") {
                    setState(() {
                      scannedNote = code;
                      noteData = data;
                      showScanner = false;
                    });
                    _saveNote(code);
                  }
                } catch (e) {}
              }
            }
          },
        ),
        Positioned(
          top: 20,
          left: 20,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 36),
            onPressed: () => setState(() => showScanner = false),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteView() {
    final amountCents = noteData!['amount'] as num? ?? 5000;
    final double amountDollars = amountCents.toDouble() / 100;
    final String formatted = amountDollars.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+\.)'),
      (m) => '${m[1]},',
    );
    final nullifier = (noteData!['nullifier'] as String?)?.substring(0, 16) ?? "????";

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            Text(
              "You own \$$formatted shielded",
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            QrImageView(
              data: jsonEncode(noteData),
              version: QrVersions.auto,
              size: 280,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 30),
            SelectableText("Nullifier: $nullifier…", style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => setState(() => noteData = null),
              icon: const Icon(Icons.delete_forever),
              label: const Text("Forget this note"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasteDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Paste BlackVault Note"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '{"version":"v5", ...}'),
          maxLines: 10,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              try {
                final data = jsonDecode(controller.text) as Map<String, dynamic>;
                if (data['version'] == 'v5' || data['version'] == 5) {
                  setState(() {
                    scannedNote = controller.text;
                    noteData = data;
                  });
                  _saveNote(controller.text);
                  Navigator.pop(ctx);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid note")),
                );
              }
            },
            child: const Text("Import"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNote(String json) async {
    final hash = sha256.convert(utf8.encode(json)).toString();
    await storage.write(key: 'note_$hash', value: json);
  }
}
