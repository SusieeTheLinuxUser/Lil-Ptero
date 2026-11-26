import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The one secure-storage instance every pref and credential store shares.
/// - resetOnError off: v10 would otherwise delete a key on a transient read
///   failure, defeating the retry in main.dart.
/// - migrateWithBackup on: the first v10 launch re-encrypts v9 data (saved API
///   keys); the backup mode keeps the originals until that finishes, so an
///   interrupted migration can't strand users without their key.
const appSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: false, migrateWithBackup: true),
);
