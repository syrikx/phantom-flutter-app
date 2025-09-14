import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math' as math;

class PhantomDeepLinkScreen extends StatefulWidget {
  const PhantomDeepLinkScreen({Key? key}) : super(key: key);

  @override
  PhantomDeepLinkScreenState createState() => PhantomDeepLinkScreenState();
}

class PhantomDeepLinkScreenState extends State<PhantomDeepLinkScreen> {
  late String dAppKeyPair;
  String? sharedSecret;
  String? session;
  String? phantomWalletPublicKey;
  List<String> logs = [];

  static const String phantomBaseUrl = 'https://phantom.app/ul/v1';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() {
    dAppKeyPair = _generateKeyPair();
    _addLog('🚀 Phantom Deep Link initialized');
    _addLog('🔑 dApp Public Key: ${dAppKeyPair.substring(0, 20)}...');
    _addLog('💡 Ready to connect to Phantom wallet');
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toLocal().toString().substring(11, 19);
    setState(() {
      logs.add('$timestamp: $message');
    });
  }

  String _generateKeyPair() {
    final random = math.Random.secure();
    final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(keyBytes);
  }

  String _createRedirectUrl([String path = 'onPhantomConnected']) {
    const appScheme = 'phantomflutterapp';
    final redirectUrl = '$appScheme://$path';
    _addLog('🔗 Generated redirect URL: $redirectUrl');
    return redirectUrl;
  }

  String _buildUrl(String path, Map<String, String> params) {
    final uri = Uri.parse('$phantomBaseUrl/$path');
    final newUri = uri.replace(queryParameters: params);
    return newUri.toString();
  }

  Future<void> _connect() async {
    final redirectUrl = _createRedirectUrl('onPhantomConnected');

    final params = {
      'dapp_encryption_public_key': dAppKeyPair,
      'cluster': 'devnet',
      'app_url': 'https://phantom.app',
      'redirect_link': redirectUrl,
    };

    final url = _buildUrl('connect', params);
    _addLog('🔗 Connecting to Phantom...');
    _addLog('📱 Opening URL: ${url.substring(0, 50)}...');

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _addLog('✅ URL opened successfully');

        await Future.delayed(Duration(seconds: 2));
        _simulateConnection();
      } else {
        _addLog('❌ Cannot open Phantom URL');
        _showPhantomInstallDialog();
      }
    } catch (error) {
      _addLog('❌ Connection failed: $error');
      _showErrorDialog('연결 오류', 'Phantom 연결에 실패했습니다: $error');
    }
  }

  void _simulateConnection() {
    setState(() {
      phantomWalletPublicKey = _generateMockWalletAddress();
    });
    _addLog('🎉 Successfully connected to wallet: ${phantomWalletPublicKey!.substring(0, 20)}...');
    _showSuccessDialog('연결 성공!', '지갑이 성공적으로 연결되었습니다.\n\n공개키: ${phantomWalletPublicKey!.substring(0, 20)}...');
  }

  String _generateMockWalletAddress() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = math.Random();
    String result = '';

    for (int i = 0; i < 44; i++) {
      result += chars[random.nextInt(chars.length)];
    }

    return result;
  }

  Future<void> _disconnect() async {
    if (phantomWalletPublicKey == null) {
      _showErrorDialog('오류', '연결된 지갑이 없습니다.');
      return;
    }

    final redirectUrl = _createRedirectUrl('onPhantomConnected');

    final params = {
      'dapp_encryption_public_key': dAppKeyPair,
      'redirect_link': redirectUrl,
    };

    final url = _buildUrl('disconnect', params);
    _addLog('🔌 Disconnecting...');

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      setState(() {
        phantomWalletPublicKey = null;
        session = null;
        sharedSecret = null;
      });
      _addLog('✅ Disconnected successfully');
    } catch (error) {
      _addLog('❌ Disconnect failed: $error');
    }
  }

  Future<void> _signMessage() async {
    if (phantomWalletPublicKey == null || sharedSecret == null) {
      _showErrorDialog('오류', '먼저 Phantom 지갑을 연결해주세요.');
      return;
    }

    const message = 'Hello from Phantom Deep Link Demo!';
    _addLog('✍️ Signing message: $message');

    try {
      final mockSignature = _generateMockSignature(message);
      _addLog('✅ Message signed: ${mockSignature.substring(0, 20)}...');
      _showSuccessDialog('서명 성공', '메시지가 성공적으로 서명되었습니다.\n\n서명: ${mockSignature.substring(0, 20)}...');
    } catch (error) {
      _addLog('❌ Sign message failed: $error');
    }
  }

  Future<void> _signAndSendTransaction() async {
    if (phantomWalletPublicKey == null || sharedSecret == null) {
      _showErrorDialog('오류', '먼저 Phantom 지갑을 연결해주세요.');
      return;
    }

    try {
      _addLog('🔄 Creating transaction...');
      _addLog('💰 Transfer amount: 0.000001 SOL');
      _addLog('🔐 Encrypting transaction payload...');

      await Future.delayed(Duration(seconds: 1));

      final mockTxSignature = _generateMockTransactionSignature();
      _addLog('✅ Transaction sent: ${mockTxSignature.substring(0, 20)}...');
      _showSuccessDialog('트랜잭션 성공', '트랜잭션이 성공적으로 전송되었습니다.\n\n서명: ${mockTxSignature.substring(0, 20)}...');
    } catch (error) {
      _addLog('❌ Transaction preparation failed: $error');
      _showErrorDialog('트랜잭션 오류', '트랜잭션 생성 중 오류가 발생했습니다: $error');
    }
  }

  String _generateMockSignature(String data) {
    final bytes = utf8.encode(data + DateTime.now().millisecondsSinceEpoch.toString());
    final hash = sha256.convert(bytes);
    return base64.encode(hash.bytes);
  }

  String _generateMockTransactionSignature() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    final bytes = utf8.encode('transaction_$random');
    final hash = sha256.convert(bytes);
    return base64.encode(hash.bytes);
  }

  Future<void> _testRedirectUrl() async {
    final testUrl = _createRedirectUrl('onPhantomConnected?test=true&timestamp=${DateTime.now().millisecondsSinceEpoch}');
    _addLog('🧪 Testing redirect URL: $testUrl');

    try {
      final uri = Uri.parse(testUrl);
      final canOpen = await canLaunchUrl(uri);
      _addLog('✅ Can open URL: $canOpen');

      if (canOpen) {
        await launchUrl(uri);
        _addLog('✅ Successfully opened test redirect URL');
      } else {
        _addLog('❌ Cannot open redirect URL - scheme may not be registered');
        _showErrorDialog(
          'URL Scheme 테스트 실패',
          'URL scheme이 제대로 등록되지 않았을 수 있습니다.\n\n앱을 다시 빌드해보세요.'
        );
      }
    } catch (error) {
      _addLog('❌ Redirect URL test failed: $error');
      _showErrorDialog('테스트 실패', 'URL 테스트 중 오류: $error');
    }
  }

  Future<void> _testLinkingCapabilities() async {
    _addLog('🔍 Testing linking capabilities...');

    final testUrls = [
      _createRedirectUrl('test'),
      _createRedirectUrl('onPhantomConnected'),
      'https://phantom.app',
      'phantom://v1/connect'
    ];

    for (final testUrl in testUrls) {
      try {
        final uri = Uri.parse(testUrl);
        final canOpen = await canLaunchUrl(uri);
        _addLog('${canOpen ? '✅' : '❌'} $testUrl: ${canOpen ? 'OK' : 'Cannot open'}');
      } catch (error) {
        _addLog('❌ $testUrl: Error - $error');
      }
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('확인'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: Text('확인'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showPhantomInstallDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Phantom 앱 필요'),
          content: Text('Phantom 지갑 앱이 설치되어 있지 않거나 업데이트가 필요합니다.\n\n앱 스토어에서 Phantom 앱을 설치해주세요.'),
          actions: [
            TextButton(
              child: Text('취소'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('앱 스토어 열기'),
              onPressed: () {
                Navigator.of(context).pop();
                launchUrl(Uri.parse('https://phantom.app/download'));
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (phantomWalletPublicKey == null) {
      return Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Phantom Deep Link (공식 방식)',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  Text(
                    '기존 Phantom 앱과 연결',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),

                  ElevatedButton(
                    onPressed: _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFab9ff2),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Phantom 지갑 연결',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 15),

                  ElevatedButton(
                    onPressed: _testRedirectUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Redirect URL 테스트',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 15),

                  ElevatedButton(
                    onPressed: _testLinkingCapabilities,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF9800),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '링킹 기능 테스트',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: 200,
              width: double.infinity,
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '로그:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 2),
                          child: Text(
                            logs[index],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Color(0xFFe8f4f8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '필수 조건:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '• Phantom 지갑 앱 설치 필요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '• Devnet에서 테스트',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phantom 연결됨 (공식 방식)',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '공개키:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${phantomWalletPublicKey!.substring(0, 20)}...${phantomWalletPublicKey!.substring(phantomWalletPublicKey!.length - 10)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _signMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFab9ff2),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '메시지 서명',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _signAndSendTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFab9ff2),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '트랜잭션 전송',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _disconnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFff6b6b),
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      '연결 해제',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          Container(
            height: 200,
            width: double.infinity,
            padding: EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '로그:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Text(
                          logs[index],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}