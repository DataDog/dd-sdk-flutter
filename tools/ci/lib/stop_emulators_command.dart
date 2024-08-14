import 'package:args/command_runner.dart';
import 'package:ci_helpers/android_helpers.dart';

class StopEmulatorsCommand extends Command {
  @override
  String get name => 'stop_emu';

  @override
  String get description => 'Stop all android simulators';

  @override
  Future<void> run() async {
    await killAllEmulators();
  }
}
