import 'dart:io';

import 'package:game_cli/game_cli.dart';

Future<void> main(List<String> args) async => exit(await runCli(args));
