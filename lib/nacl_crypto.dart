import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class NaClCrypto {
  static const int keyLength = 32;
  static const int nonceLength = 24;

  // Generate a new key pair
  static Map<String, Uint8List> generateKeyPair() {
    final random = Random.secure();
    final privateKey = Uint8List(keyLength);
    for (int i = 0; i < keyLength; i++) {
      privateKey[i] = random.nextInt(256);
    }

    // For simplicity, we'll use the private key as both private and public
    // In a real implementation, you'd use proper Curve25519 key generation
    final publicKey = _derivePublicKey(privateKey);

    return {
      'publicKey': publicKey,
      'secretKey': privateKey,
    };
  }

  static Uint8List _derivePublicKey(Uint8List privateKey) {
    // Simple hash-based public key derivation for demonstration
    // In production, use proper Curve25519 point multiplication
    final hash = sha256.convert(privateKey).bytes;
    return Uint8List.fromList(hash);
  }

  // Generate random bytes
  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  // Create shared secret using X25519 key exchange (simplified)
  static Uint8List createSharedSecret(Uint8List myPrivateKey, Uint8List theirPublicKey) {
    // Simplified shared secret creation using HMAC
    // In production, use proper X25519 key exchange
    final hmac = Hmac(sha256, myPrivateKey);
    final digest = hmac.convert(theirPublicKey);
    return Uint8List.fromList(digest.bytes);
  }

  // Simple XOR encryption (for demo purposes - not production ready)
  static Map<String, Uint8List> encrypt(Uint8List message, Uint8List sharedSecret) {
    final nonce = randomBytes(nonceLength);

    // Create a key stream from shared secret and nonce
    final keyStream = _createKeyStream(sharedSecret, nonce, message.length);

    // XOR encrypt the message
    final encrypted = Uint8List(message.length);
    for (int i = 0; i < message.length; i++) {
      encrypted[i] = message[i] ^ keyStream[i];
    }

    return {
      'nonce': nonce,
      'ciphertext': encrypted,
    };
  }

  // Simple XOR decryption
  static Uint8List? decrypt(Uint8List ciphertext, Uint8List nonce, Uint8List sharedSecret) {
    try {
      // Create the same key stream used for encryption
      final keyStream = _createKeyStream(sharedSecret, nonce, ciphertext.length);

      // XOR decrypt the ciphertext
      final decrypted = Uint8List(ciphertext.length);
      for (int i = 0; i < ciphertext.length; i++) {
        decrypted[i] = ciphertext[i] ^ keyStream[i];
      }

      return decrypted;
    } catch (e) {
      print('Decryption failed: $e');
      return null;
    }
  }

  // Create a key stream from shared secret and nonce
  static Uint8List _createKeyStream(Uint8List sharedSecret, Uint8List nonce, int length) {
    final keyStream = Uint8List(length);
    final combined = Uint8List.fromList([...sharedSecret, ...nonce]);

    for (int i = 0; i < length; i++) {
      final block = [...combined, i >> 24, i >> 16, i >> 8, i];
      final hash = sha256.convert(block);
      keyStream[i] = hash.bytes[i % 32];
    }

    return keyStream;
  }

  // Base58 encode
  static String base58Encode(Uint8List bytes) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

    if (bytes.isEmpty) return '';

    // Convert to big integer
    BigInt num = BigInt.zero;
    for (int byte in bytes) {
      num = num * BigInt.from(256) + BigInt.from(byte);
    }

    // Convert to base58
    String result = '';
    while (num > BigInt.zero) {
      final remainder = num % BigInt.from(58);
      num = num ~/ BigInt.from(58);
      result = alphabet[remainder.toInt()] + result;
    }

    // Add leading zeros
    for (int byte in bytes) {
      if (byte == 0) {
        result = '1' + result;
      } else {
        break;
      }
    }

    return result;
  }

  // Base58 decode
  static Uint8List? base58Decode(String encoded) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

    if (encoded.isEmpty) return Uint8List(0);

    // Count leading zeros
    int leadingZeros = 0;
    for (int i = 0; i < encoded.length; i++) {
      if (encoded[i] == '1') {
        leadingZeros++;
      } else {
        break;
      }
    }

    // Convert from base58
    BigInt num = BigInt.zero;
    for (int i = 0; i < encoded.length; i++) {
      final char = encoded[i];
      final index = alphabet.indexOf(char);
      if (index == -1) return null;
      num = num * BigInt.from(58) + BigInt.from(index);
    }

    // Convert to bytes
    final List<int> bytes = [];
    while (num > BigInt.zero) {
      bytes.insert(0, (num % BigInt.from(256)).toInt());
      num = num ~/ BigInt.from(256);
    }

    // Add leading zeros
    for (int i = 0; i < leadingZeros; i++) {
      bytes.insert(0, 0);
    }

    return Uint8List.fromList(bytes);
  }
}