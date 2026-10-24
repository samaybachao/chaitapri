import 'dart:convert';

/// The save format version written by this build.
///
/// When the saved data layout changes, bump this and add a step to [migrateSave].
const int kSaveVersion = 1;

/// A save as stored on disk: a checksum-protected wrapper around the game JSON.
class SaveEnvelope {
  const SaveEnvelope({required this.version, required this.sequence, required this.payload});

  /// Format version of [payload].
  final int version;

  /// Counts up with every save, so the newest of the two slots can be found.
  final int sequence;

  /// The game state as a JSON string.
  final String payload;
}

/// 32-bit FNV-1a hash of [text] (UTF-16 code units). Detects truncated or
/// corrupted saves; it is not meant as security.
int checksum(String text) {
  int hash = 0x811C9DC5;
  for (final int unit in text.codeUnits) {
    hash = hash ^ unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Wraps [payload] (JSON text of the game state) for storage.
String encodeEnvelope({required int sequence, required String payload}) {
  return jsonEncode(<String, Object?>{
    'v': kSaveVersion,
    'n': sequence,
    'c': checksum(payload),
    'p': payload,
  });
}

/// Reads a stored save. Returns null when [raw] is damaged in any way.
SaveEnvelope? decodeEnvelope(String raw) {
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final Object? version = decoded['v'];
    final Object? sequence = decoded['n'];
    final Object? sum = decoded['c'];
    final Object? payload = decoded['p'];
    if (version is! int || sequence is! int || sum is! int || payload is! String) {
      return null;
    }
    if (checksum(payload) != sum) {
      return null;
    }
    return SaveEnvelope(version: version, sequence: sequence, payload: payload);
  } on FormatException {
    return null;
  }
}

/// Upgrades the JSON of an older save to [kSaveVersion]. Returns null when the
/// version is unknown (for example a save made by a newer app version).
Map<String, dynamic>? migrateSave(int version, Map<String, dynamic> data) {
  if (version == kSaveVersion) {
    return data;
  }
  // Example for a future version 2:
  //   if (version == 1) { data['newField'] = 0; version = 2; }
  return null;
}
