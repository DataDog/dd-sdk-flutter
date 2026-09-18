import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:ci_helpers/android_helpers.dart';
import 'package:ci_helpers/ios_helpers.dart';

class SimulatorCommand extends Command {
  @override
  String get name => 'start_sim';

  @override
  String get description => 'Start a simulator or emulator for the platform';

  SimulatorCommand() {
    argParser.addOption('platform',
        allowed: ['ios', 'android'],
        mandatory: true,
        help: 'The platform to start the simulator or emulator for.');
    argParser.addOption('sdk', help: 'The SDK (or API target) to use.');
    argParser.addOption('device',
        help: 'The device (or emulator name) to use.');
  }

  @override
  Future<void> run() async {
    final args = argResults;
    if (args == null) {
      print('Args are null?');
      return;
    }

    final platform = args.option('platform');
    switch (platform) {
      case "ios":
        await _startIos(args);
        break;
      case "android":
        await _startAndroid(args);
    }
  }

  Future<void> _startIos(ArgResults args) async {
    final sdk = args.option('sdk');
    if (sdk == null) {
      print("Must supply an `sdk` to launch an iOS simulator");
      return;
    }
    final device = args.option('device');
    print('Launching iOS Simulator: SDK: $sdk, Device Name: $device');
    await launchIosSimulator(sdk, device);
  }

  Future<void> _startAndroid(ArgResults args) async {
    final sdk = args.option('sdk');
    final device = args.option('device');
    if (sdk == null && device == null) {
      print(
          'Must supply an API target (sdk) or emulator name (device) to launch an Android emulator.');
      return;
    }
    print(
        'Launching Android Emulator: API Target: $sdk, Emulator Name $device');
    await launchAndroidEmulator(apiLevel: sdk, emulatorName: device);
  }
}
