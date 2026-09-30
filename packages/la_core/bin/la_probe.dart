import 'dart:io';

import 'package:la_core/la_core.dart';

const String laProbeVersion = '0.0.1-spike.1';

Future<void> main(List<String> args) async {
  if (args.contains('--version')) {
    stdout.writeln('la_probe $laProbeVersion (dart ${Platform.version})');
    return;
  }
  stdout.writeln((await SelfProbe().run()).describe());
}
