import 'package:flutter/material.dart';
import 'phantom_wallet_service.dart';
import 'wallet_screen.dart';
import 'phantom_deep_link_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phantom Flutter App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const PhantomApp(),
    );
  }
}

class PhantomApp extends StatefulWidget {
  const PhantomApp({Key? key}) : super(key: key);

  @override
  PhantomAppState createState() => PhantomAppState();
}

class PhantomAppState extends State<PhantomApp> {
  bool useDeepLink = false;
  final PhantomWalletService walletService = PhantomWalletService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Phantom 지갑 테스트 앱'),
        backgroundColor: Color(0xFFab9ff2),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                useDeepLink = !useDeepLink;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                useDeepLink ? 'SDK 방식으로 전환' : 'Deep Link 방식으로 전환',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: useDeepLink
          ? const PhantomDeepLinkScreen()
          : WalletScreen(),
      ),
    );
  }
}
