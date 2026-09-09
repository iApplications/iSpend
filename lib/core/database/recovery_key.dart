import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class RecoveryKeyEnvelope {
  const RecoveryKeyEnvelope({
    required this.salt,
    required this.nonce,
    required this.ciphertext,
  });

  static const version = 1;
  static const iterations = 3;
  static const memoryKib = 65536;
  static const parallelism = 4;

  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertext;

  Map<String, Object> toJson() => {
    'version': version,
    'kdf': 'argon2id',
    'iterations': iterations,
    'memory_kib': memoryKib,
    'parallelism': parallelism,
    'cipher': 'aes-256-gcm',
    'salt': base64UrlEncode(salt),
    'nonce': base64UrlEncode(nonce),
    'ciphertext': base64UrlEncode(ciphertext),
  };

  factory RecoveryKeyEnvelope.fromJson(Map<String, dynamic> json) {
    if (json['version'] != version ||
        json['kdf'] != 'argon2id' ||
        json['iterations'] != iterations ||
        json['memory_kib'] != memoryKib ||
        json['parallelism'] != parallelism ||
        json['cipher'] != 'aes-256-gcm') {
      throw const FormatException('Unsupported recovery key envelope.');
    }
    return RecoveryKeyEnvelope(
      salt: base64Url.decode(json['salt'] as String),
      nonce: base64Url.decode(json['nonce'] as String),
      ciphertext: base64Url.decode(json['ciphertext'] as String),
    );
  }
}

abstract interface class RecoveryKeyOperations {
  Future<RecoveryKeyEnvelope> wrap({
    required String databaseKey,
    required String passphrase,
  });

  Future<String> unwrap({
    required RecoveryKeyEnvelope envelope,
    required String passphrase,
  });
}

class RecoveryKeyService implements RecoveryKeyOperations {
  const RecoveryKeyService();

  @override
  Future<RecoveryKeyEnvelope> wrap({
    required String databaseKey,
    required String passphrase,
  }) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final ciphertext = await Isolate.run(
      () => _encrypt((databaseKey, passphrase, salt, nonce)),
    );
    return RecoveryKeyEnvelope(
      salt: salt,
      nonce: nonce,
      ciphertext: ciphertext,
    );
  }

  @override
  Future<String> unwrap({
    required RecoveryKeyEnvelope envelope,
    required String passphrase,
  }) async {
    try {
      return await Isolate.run(() => _decrypt((envelope, passphrase)));
    } catch (_) {
      throw const RecoveryPassphraseException();
    }
  }

  static Uint8List _encrypt((String, String, Uint8List, Uint8List) input) {
    final (databaseKey, passphrase, salt, nonce) = input;
    final key = _deriveKey(passphrase, salt);
    try {
      final cipher = _cipher(true, key, nonce);
      return cipher.process(Uint8List.fromList(utf8.encode(databaseKey)));
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  static String _decrypt((RecoveryKeyEnvelope, String) input) {
    final (envelope, passphrase) = input;
    final key = _deriveKey(passphrase, envelope.salt);
    try {
      final cipher = _cipher(false, key, envelope.nonce);
      return utf8.decode(cipher.process(envelope.ciphertext));
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  static Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final parameterSalt = Uint8List.fromList(salt);
    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      parameterSalt,
      desiredKeyLength: 32,
      iterations: RecoveryKeyEnvelope.iterations,
      memory: RecoveryKeyEnvelope.memoryKib,
      lanes: RecoveryKeyEnvelope.parallelism,
      version: Argon2Parameters.ARGON2_VERSION_13,
    );
    final generator = Argon2BytesGenerator()..init(parameters);
    final password = Uint8List.fromList(utf8.encode(passphrase));
    final output = Uint8List(32);
    try {
      generator.deriveKey(password, 0, output, 0);
      return output;
    } finally {
      password.fillRange(0, password.length, 0);
      parameterSalt.fillRange(0, parameterSalt.length, 0);
    }
  }

  static GCMBlockCipher _cipher(
    bool encrypting,
    Uint8List key,
    Uint8List nonce,
  ) {
    return GCMBlockCipher(AESEngine())..init(
      encrypting,
      AEADParameters(
        KeyParameter(key),
        128,
        nonce,
        Uint8List.fromList(utf8.encode('ispend-recovery-key-v1')),
      ),
    );
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

class RecoveryPassphraseException implements Exception {
  const RecoveryPassphraseException();
}
