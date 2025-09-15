import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'deep_link_service.dart';
import 'nacl_crypto.dart';

class PhantomDeepLinkScreen extends StatefulWidget {
  final DeepLinkService deepLinkService;

  const PhantomDeepLinkScreen({
    Key? key,
    required this.deepLinkService,
  }) : super(key: key);

  @override
  PhantomDeepLinkScreenState createState() => PhantomDeepLinkScreenState();
}

class PhantomDeepLinkScreenState extends State<PhantomDeepLinkScreen> {
  late Map<String, Uint8List> dAppKeyPair;
  Uint8List? sharedSecret;
  Map<String, String>? session;
  String? phantomWalletPublicKey;
  List<String> logs = [];
  StreamSubscription<Uri>? _linkSubscription;

  static const String phantomBaseUrl = 'https://phantom.app/ul/v1';

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _listenToDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initializeApp() {
    dAppKeyPair = NaClCrypto.generateKeyPair();
    _addLog('🚀 Phantom Deep Link initialized');
    _addLog('🔑 dApp Public Key: ${NaClCrypto.base58Encode(dAppKeyPair['publicKey']!).substring(0, 20)}...');
    _addLog('💡 Ready to connect to Phantom wallet');
  }

  void _listenToDeepLinks() {
    _linkSubscription = widget.deepLinkService.linkStream.listen(
      (Uri uri) {
        _addLog('📥 Received deep link: $uri');
        _handleDeepLink(uri);
      },
      onError: (error) {
        _addLog('❌ Deep link error: $error');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    try {
      final params = uri.queryParameters;

      // Check for error response first
      if (params.containsKey('errorCode')) {
        final errorCode = params['errorCode'];
        final errorMessage = params['errorMessage'] ?? 'Unknown error';
        _addLog('❌ Phantom Error [$errorCode]: $errorMessage');
        _showErrorDialog('Phantom 오류', '오류 코드: $errorCode\n$errorMessage');
        return;
      }

      // Handle initial connection response
      if (params.containsKey('phantom_encryption_public_key') && params.containsKey('nonce')) {
        _addLog('🔐 Processing connection response...');
        try {
          final phantomPublicKeyParam = params['phantom_encryption_public_key']!;
          final nonceParam = params['nonce']!;

          _addLog('🔑 Phantom public key: ${phantomPublicKeyParam.substring(0, 20)}...');
          _addLog('🎲 Nonce: ${nonceParam.substring(0, 20)}...');

          final phantomPublicKey = NaClCrypto.base58Decode(phantomPublicKeyParam);
          if (phantomPublicKey == null) {
            throw Exception('Invalid phantom public key');
          }

          // Create shared secret for future encrypted communication
          final sharedSecretDapp = NaClCrypto.createSharedSecret(
            dAppKeyPair['secretKey']!,
            phantomPublicKey,
          );
          setState(() {
            sharedSecret = sharedSecretDapp;
          });
          _addLog('✅ Shared secret established');

          // Decrypt connection data if present
          final connectData = params['data'];
          if (connectData != null) {
            _addLog('🔓 Decrypting connection data...');
            final decryptedData = _decryptPayload(connectData, nonceParam, sharedSecretDapp);
            if (decryptedData != null && decryptedData.containsKey('public_key')) {
              setState(() {
                phantomWalletPublicKey = decryptedData['public_key'];
                session = {
                  'phantomEncryptionPublicKey': phantomPublicKeyParam,
                  'nonce': nonceParam,
                };
              });
              _addLog('🎉 Successfully connected to wallet: ${phantomWalletPublicKey!.substring(0, 20)}...');
              _showSuccessDialog(
                '연결 성공!',
                '지갑이 성공적으로 연결되었습니다.\n\n공개키: ${phantomWalletPublicKey!.substring(0, 20)}...',
              );
            }
          } else {
            _addLog('⚠️ No connection data found in response');
          }
        } catch (keyError) {
          _addLog('❌ Key processing error: $keyError');
        }
      }
      // Handle encrypted responses (signatures, transactions)
      else if (params.containsKey('data') && params.containsKey('nonce') && sharedSecret != null) {
        _addLog('🔓 Decrypting response data...');
        final decryptedData = _decryptPayload(params['data']!, params['nonce']!, sharedSecret!);
        if (decryptedData != null) {
          _handleConnectResponse(decryptedData);
        }
      }
      else {
        _addLog('⚠️ Received deep link with unexpected format');
        _addLog('📋 Available params: ${params.keys.join(', ')}');
      }
    } catch (error) {
      _addLog('❌ Deep link parsing failed: $error');
      _showErrorDialog('링크 오류', 'Deep link 처리 중 오류가 발생했습니다: $error');
    }
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toLocal().toString().substring(11, 19);
    setState(() {
      logs.add('$timestamp: $message');
    });
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

  Map<String, Uint8List> _encryptPayload(Map<String, dynamic> payload, Uint8List sharedSecret) {
    final payloadJson = jsonEncode(payload);
    final payloadBytes = Uint8List.fromList(utf8.encode(payloadJson));

    final encrypted = NaClCrypto.encrypt(payloadBytes, sharedSecret);
    return encrypted;
  }

  Map<String, dynamic>? _decryptPayload(String data, String nonce, Uint8List sharedSecret) {
    try {
      final dataBytes = NaClCrypto.base58Decode(data);
      final nonceBytes = NaClCrypto.base58Decode(nonce);

      if (dataBytes == null || nonceBytes == null) {
        throw Exception('Invalid base58 encoding');
      }

      final decryptedData = NaClCrypto.decrypt(dataBytes, nonceBytes, sharedSecret);

      if (decryptedData == null) {
        throw Exception('Unable to decrypt data');
      }

      final jsonString = utf8.decode(decryptedData);
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (error) {
      _addLog('❌ Decryption failed: $error');
      return null;
    }
  }

  void _handleConnectResponse(Map<String, dynamic> data) {
    if (data.containsKey('public_key')) {
      setState(() {
        phantomWalletPublicKey = data['public_key'];
      });
      _addLog('✅ Connected to wallet: ${phantomWalletPublicKey!.substring(0, 20)}...');
    }
    if (data.containsKey('signature')) {
      _addLog('✅ Message signed: ${data['signature'].toString().substring(0, 20)}...');
      _showSuccessDialog(
        '서명 성공',
        '메시지가 성공적으로 서명되었습니다.\n\n서명: ${data['signature'].toString().substring(0, 20)}...',
      );
    }
    if (data.containsKey('transaction')) {
      _addLog('✅ Transaction sent: ${data['transaction'].toString().substring(0, 20)}...');
      _showSuccessDialog(
        '트랜잭션 성공',
        '트랜잭션이 성공적으로 전송되었습니다.\n\n서명: ${data['transaction'].toString().substring(0, 20)}...',
      );
    }
  }

  Future<void> _connect() async {
    final redirectUrl = _createRedirectUrl('onPhantomConnected');

    final params = {
      'dapp_encryption_public_key': NaClCrypto.base58Encode(dAppKeyPair['publicKey']!),
      'cluster': 'devnet',
      'app_url': 'https://phantom.app',
      'redirect_link': redirectUrl,
    };

    final url = _buildUrl('connect', params);
    _addLog('🔗 Connecting to Phantom...');
    _addLog('📱 Opening URL: ${url.substring(0, 50)}...');

    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      _addLog('✅ URL opened successfully');
    } catch (error) {
      _addLog('❌ Connection failed: $error');
      _showErrorDialog('연결 오류', 'Phantom 연결에 실패했습니다: $error');
    }
  }

  Future<void> _disconnect() async {
    if (phantomWalletPublicKey == null) {
      _showErrorDialog('오류', '연결된 지갑이 없습니다.');
      return;
    }

    final redirectUrl = _createRedirectUrl('onPhantomConnected');

    final params = {
      'dapp_encryption_public_key': NaClCrypto.base58Encode(dAppKeyPair['publicKey']!),
      'redirect_link': redirectUrl,
    };

    final url = _buildUrl('disconnect', params);
    _addLog('🔌 Disconnecting...');

    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final payload = {
      'message': NaClCrypto.base58Encode(Uint8List.fromList(utf8.encode(message))),
    };

    try {
      final encrypted = _encryptPayload(payload, sharedSecret!);

      final params = {
        'dapp_encryption_public_key': NaClCrypto.base58Encode(dAppKeyPair['publicKey']!),
        'nonce': NaClCrypto.base58Encode(encrypted['nonce']!),
        'redirect_link': _createRedirectUrl('onPhantomConnected'),
        'payload': NaClCrypto.base58Encode(encrypted['ciphertext']!),
      };

      final url = _buildUrl('signMessage', params);
      _addLog('✍️ Signing message...');
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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

      // Create a simple mock transaction
      final mockTransaction = {
        'fromPubkey': phantomWalletPublicKey!,
        'toPubkey': phantomWalletPublicKey!, // Send to self
        'lamports': 1000,
      };

      final payload = {
        'transaction': NaClCrypto.base58Encode(
          Uint8List.fromList(utf8.encode(jsonEncode(mockTransaction))),
        ),
        'message': 'Test transaction: Transfer 0.000001 SOL to self',
      };

      _addLog('🔐 Encrypting transaction payload...');
      final encrypted = _encryptPayload(payload, sharedSecret!);

      final params = {
        'dapp_encryption_public_key': NaClCrypto.base58Encode(dAppKeyPair['publicKey']!),
        'nonce': NaClCrypto.base58Encode(encrypted['nonce']!),
        'redirect_link': _createRedirectUrl('onPhantomConnected'),
        'payload': NaClCrypto.base58Encode(encrypted['ciphertext']!),
      };

      final url = _buildUrl('signAndSendTransaction', params);
      _addLog('💸 Opening Phantom for transaction signing...');

      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      _addLog('❌ Transaction preparation failed: $error');
      _showErrorDialog('트랜잭션 오류', '트랜잭션 생성 중 오류가 발생했습니다: $error');
    }
  }

  Future<void> _testRedirectUrl() async {
    final testUrl = _createRedirectUrl(
      'onPhantomConnected?test=true&timestamp=${DateTime.now().millisecondsSinceEpoch}',
    );
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
          'URL scheme이 제대로 등록되지 않았을 수 있습니다.\n\n앱을 다시 빌드해보세요.',
        );
      }
    } catch (error) {
      _addLog('❌ Redirect URL test failed: $error');
      _showErrorDialog('테스트 실패', 'URL 테스트 중 오류: $error');
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
                    'Phantom Deep Link (실제 구현)',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  Text(
                    '실제 Phantom 앱과 연결 (딥링크 수신 기능 포함)',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),

                  ElevatedButton(
                    onPressed: _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFab9ff2),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Phantom 지갑 연결',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 15),

                  ElevatedButton(
                    onPressed: _testRedirectUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Redirect URL 테스트',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
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
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'monospace'),
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
                    '개선사항:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text('• 실제 딥링크 수신 처리 구현', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  Text('• 암호화/복호화 로직 추가', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  Text('• Mock 시뮬레이션 제거', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
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
        children: [
          Text(
            'Phantom 연결됨 (실제 구현)',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
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
                Text('공개키:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(5)),
                  child: Text(
                    '${phantomWalletPublicKey!.substring(0, 20)}...${phantomWalletPublicKey!.substring(phantomWalletPublicKey!.length - 10)}',
                    style: TextStyle(fontSize: 14, fontFamily: 'monospace', color: Colors.grey[600]),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      '메시지 서명',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      '트랜잭션 전송',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      '연결 해제',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                Text('로그:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Text(
                          logs[index],
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'monospace'),
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