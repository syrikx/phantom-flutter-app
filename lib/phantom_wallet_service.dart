import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PhantomWalletService {
  static const String _connectionKey = 'phantom_connection';
  static const String _walletAddressKey = 'phantom_wallet_address';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  bool _isConnected = false;
  String? _walletAddress;
  List<String> _addresses = [];

  bool get isConnected => _isConnected;
  String? get walletAddress => _walletAddress;
  List<String> get addresses => _addresses;

  Future<bool> connect({String provider = 'google'}) async {
    try {
      await Future.delayed(Duration(seconds: 1));

      _isConnected = true;
      _walletAddress = _generateMockAddress();
      _addresses = [_walletAddress!];

      await _storage.write(key: _connectionKey, value: 'true');
      await _storage.write(key: _walletAddressKey, value: _walletAddress);

      return true;
    } catch (error) {
      throw Exception('연결 실패: $error');
    }
  }

  Future<void> disconnect() async {
    try {
      _isConnected = false;
      _walletAddress = null;
      _addresses = [];

      await _storage.delete(key: _connectionKey);
      await _storage.delete(key: _walletAddressKey);
    } catch (error) {
      throw Exception('연결 해제 실패: $error');
    }
  }

  Future<String> signMessage(String message) async {
    if (!_isConnected) {
      throw Exception('지갑이 연결되지 않았습니다');
    }

    await Future.delayed(Duration(seconds: 1));

    final messageBytes = utf8.encode(message);
    final hash = sha256.convert(messageBytes);
    final mockSignature = _generateMockSignature(hash.toString());

    return mockSignature;
  }

  Future<String> signAndSendTransaction(Map<String, dynamic> transaction) async {
    if (!_isConnected) {
      throw Exception('지갑이 연결되지 않았습니다');
    }

    await Future.delayed(Duration(seconds: 2));

    final mockTxSignature = _generateMockTransactionSignature();

    return mockTxSignature;
  }

  Future<void> restoreConnection() async {
    try {
      final connectionStatus = await _storage.read(key: _connectionKey);
      final address = await _storage.read(key: _walletAddressKey);

      if (connectionStatus == 'true' && address != null) {
        _isConnected = true;
        _walletAddress = address;
        _addresses = [address];
      }
    } catch (error) {
      // Silently ignore connection restoration errors
    }
  }

  String _generateMockAddress() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String result = '';

    for (int i = 0; i < 44; i++) {
      result += chars[(random + i) % chars.length];
    }

    return result;
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
}