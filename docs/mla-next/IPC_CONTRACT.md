# MLA-Next IPC v1 — Entwurf, noch nicht implementiert

Ziel: unprivilegierter Dart-Host (`packages/la_core` nach Issue #59), GTK-Client. Unix-Domain-Socket in einem privaten Verzeichnis unter XDG_RUNTIME_DIR. Ein Host bindet; GTK und ein optionaler Flutter-Adapter sind Clients. Kein zweiter C-Server am selben Pfad.

## Wire

JSON-RPC 2.0 über UTF-8 JSONL: ein Objekt plus LF je Frame, maximal 65536 Bytes **vor** Parsing. Keine Batch-Requests in v1. `mla.hello` mit Protokollversion/Capabilities zuerst; danach `backup.list`, `backup.watch` und nur später `backup.startUserUnit`. Responses spiegeln die Request-ID; Notifications (`backup.statusChanged`) haben keine ID und keine Antwort.

Beispiel (nur Vertragsanregung, kein vorhandener Backend-Code):

```json
{"jsonrpc":"2.0","id":"r1","method":"mla.hello","params":{"client":"mla-gtk","protocol":1}}
{"jsonrpc":"2.0","id":"r1","result":{"server":"mla-core","protocol":1,"capabilities":["backup.list"]}}
```

`backup.list` liefert `{revision,observedAt,jobs}`; Jobs tragen Unit-ID, Scope (`user|system`), Zustand (`ok|warn|crit|unknown`), Phase und redigierte Evidenz. `stale` ist UI-/Transportstatus, nicht stillschweigend `ok`. Event-Seq/Revisionslücken, Disconnect und Reconnect lösen vollständigen Snapshot-Neuabruf aus. Limitierte Schreibqueue, Timeouts, geordnete Writes und Schutz gegen doppelte Start-Requests gehören zum Implementierungsgate.

## Sicherheitsgrenze

Socket-Verzeichnis 0700, Socket 0600, Eigentümer und Peer-UID prüfen. SO_PEERCRED schützt nicht vor kompromittierten Prozessen derselben UID. Kein Shell-Execute- oder Root-Methodenname im Wire. Schreibende Aktionen erfordern serverseitig festgelegte Capabilities, erneut validierte erlaubte User-Unit, Nutzerbestätigung und Audit; System-Units bleiben lesend. Keine Tokens, Restic-Passwörter oder rohen Journalausgaben übertragen. Die vorhandene polkit-Grenze bleibt getrennt.

Standard-JSON-RPC-Fehler für Parsing/Request/Method/Parameter; definierte anwendungsspezifische Fehler für nicht verfügbar, verboten, beschäftigt und Timeout. Fehlerdaten nur Code, messageKey und retryable, keine Secrets. Ein Schema und positive/negative Contract-Fixtures sind ein eigenes späteres Task-Paket, nicht durch diesen Text als implementiert behauptet.
