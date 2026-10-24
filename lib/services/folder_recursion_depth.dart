/// Reichweite der Ordnersuche im Benutzerverzeichnis (#46).
///
/// Der Wert kommt aus der Konfigurationsdatei des Benutzers
/// (`$HOME/.config/linux-assistant/config.json`) und ist damit frei
/// manipulierbar. Er wird nie ungeprueft verwendet: die Klemme haelt ihn im
/// Bereich [kMinFolderRecursionDepth]..[kMaxFolderRecursionDepth], und ein
/// Wert, der keine Zahl ist, faellt auf [kDefaultFolderRecursionDepth]
/// zurueck.
///
/// Ohne diese Klemme produzierte ein Textwert im Config einen TypeError im
/// `final int`-Cast — die Ordnersuche lieferte dann eine leere Liste, und
/// der Benutzer wusste nicht, warum seine Ordner fehlen.
library;

/// Tiefe, die verwendet wird, wenn der Wert fehlt oder unlesbar ist.
const int kDefaultFolderRecursionDepth = 3;

/// Kleinste sinnvolle Tiefe. Tiefe 0 wuerde nur das Home-Verzeichnis selbst
/// listen.
const int kMinFolderRecursionDepth = 1;

/// Groesste zulaessige Tiefe. Tiefe 10 in einem Home-Verzeichnis mit
/// `node_modules` oder einem synchronisierten Cloud-Ordner sind bereits
/// hunderttausende Verzeichnisse.
const int kMaxFolderRecursionDepth = 10;

/// Klemmt [rawValue] auf [kMinFolderRecursionDepth]..[kMaxFolderRecursionDepth].
///
/// Angenommen wird eine `int` und ein Text, der eine Zahl enthaelt
/// (`"5"`). Alles andere — ein `bool`, ein `double`, eine Liste oder ein
/// Text wie `"'; touch /tmp/pwned"` — faellt auf
/// [kDefaultFolderRecursionDepth] zurueck.
///
/// Die Klemmung passiert auf `BigInt`, damit ein riesiger Wert nicht
/// ueberlaeuft: `"99999999999999999999"` wird auf
/// [kMaxFolderRecursionDepth] gesenkt und nicht auf eine
/// Zufallszahl gekuerzt.
int clampFolderRecursionDepth(dynamic rawValue) {
  final BigInt? parsed = _parseAsBigInt(rawValue);
  if (parsed == null) {
    return kDefaultFolderRecursionDepth;
  }
  final BigInt min = BigInt.from(kMinFolderRecursionDepth);
  final BigInt max = BigInt.from(kMaxFolderRecursionDepth);
  final BigInt clamped = parsed < min ? min : (parsed > max ? max : parsed);
  return clamped.toInt();
}

/// Liest [rawValue] als Ganzzahl, oder `null`, wenn es keine ist.
BigInt? _parseAsBigInt(dynamic rawValue) {
  if (rawValue is int) {
    return BigInt.from(rawValue);
  }
  if (rawValue is String) {
    // `BigInt.tryParse` akzeptiert nur Ziffern mit optionalem Vorzeichen —
    // kein "3.5", kein "0x10", kein Text mit Metazeichen.
    return BigInt.tryParse(rawValue.trim());
  }
  return null;
}
