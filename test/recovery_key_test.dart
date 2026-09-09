import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/database/recovery_key.dart';

void main() {
  test(
    'wraps and unwraps a database key with the fixed Argon2id parameters',
    () async {
      const service = RecoveryKeyService();
      final envelope = await service.wrap(
        databaseKey: 'test-database-key',
        passphrase: 'correct horse battery staple',
      );

      final json = envelope.toJson();
      expect(json['kdf'], 'argon2id');
      expect(json['iterations'], 3);
      expect(json['memory_kib'], 65536);
      expect(json['parallelism'], 4);
      expect(json['cipher'], 'aes-256-gcm');
      expect(
        RecoveryKeyEnvelope.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        ).toJson(),
        json,
      );

      expect(
        await service.unwrap(
          envelope: envelope,
          passphrase: 'correct horse battery staple',
        ),
        'test-database-key',
      );
      await expectLater(
        service.unwrap(envelope: envelope, passphrase: 'wrong passphrase'),
        throwsA(isA<RecoveryPassphraseException>()),
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
