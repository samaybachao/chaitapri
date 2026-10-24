// Changes the application id (package name) everywhere it is written in the project.
//
//   dart run tool/rename_package.dart com.yourname.chaitapri
//
// Run it BEFORE your first upload to Google Play: the id can never change afterwards.
// Updates: lib/app/constants.dart, android/app/build.gradle.kts, MainActivity.kt (moved to
// the matching folder). Then run `flutter clean` once.
import 'dart:io';

final RegExp idPattern = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');

const Set<String> reserved = <String>{
  'abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch', 'char', 'class', 'const',
  'continue', 'default', 'do', 'double', 'else', 'enum', 'extends', 'final', 'finally', 'float',
  'for', 'goto', 'if', 'implements', 'import', 'instanceof', 'int', 'interface', 'long', 'native',
  'new', 'package', 'private', 'protected', 'public', 'return', 'short', 'static', 'strictfp',
  'super', 'switch', 'synchronized', 'this', 'throw', 'throws', 'transient', 'try', 'void',
  'volatile', 'while', 'null', 'true', 'false',
};

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/rename_package.dart com.yourname.chaitapri');
    exit(64);
  }
  final String newId = args.first.trim();
  if (!idPattern.hasMatch(newId)) {
    stderr.writeln('"$newId" is not a valid application id. Use lower-case letters, digits and '
        'underscores in at least two parts separated by dots, e.g. com.yourname.chaitapri');
    exit(64);
  }
  if (newId.split('.').any(reserved.contains)) {
    stderr.writeln('A part of "$newId" is a reserved Java word (for example "new" or "int").');
    exit(64);
  }
  if (newId.startsWith('com.example')) {
    stderr.writeln('Google Play does not accept ids that start with com.example.');
    exit(64);
  }

  final File constants = File('lib/app/constants.dart');
  final File gradle = File('android/app/build.gradle.kts');
  if (!constants.existsSync() || !gradle.existsSync()) {
    stderr.writeln('Run this from the project root (the folder with pubspec.yaml).');
    exit(66);
  }

  final RegExpMatch? current = RegExp(
    r"const String kApplicationId = '([^']+)';",
  ).firstMatch(constants.readAsStringSync());
  if (current == null) {
    stderr.writeln('Could not find kApplicationId in lib/app/constants.dart.');
    exit(65);
  }
  final String oldId = current.group(1) ?? '';
  if (oldId == newId) {
    stdout.writeln('The id is already $newId. Nothing to do.');
    return;
  }

  constants.writeAsStringSync(
    constants.readAsStringSync().replaceFirst(
      "const String kApplicationId = '$oldId';",
      "const String kApplicationId = '$newId';",
    ),
  );

  final String gradleText = gradle
      .readAsStringSync()
      .replaceAll('namespace = "$oldId"', 'namespace = "$newId"')
      .replaceAll('applicationId = "$oldId"', 'applicationId = "$newId"');
  gradle.writeAsStringSync(gradleText);

  final File oldActivity = File('android/app/src/main/kotlin/${oldId.replaceAll('.', '/')}/MainActivity.kt');
  if (oldActivity.existsSync()) {
    final String source = oldActivity.readAsStringSync().replaceFirst('package $oldId', 'package $newId');
    final File newActivity = File('android/app/src/main/kotlin/${newId.replaceAll('.', '/')}/MainActivity.kt');
    newActivity.parent.createSync(recursive: true);
    newActivity.writeAsStringSync(source);
    oldActivity.deleteSync();
    // Remove the now empty folders of the old package.
    Directory dir = oldActivity.parent;
    final String stop = 'android/app/src/main/kotlin';
    while (dir.path.replaceAll('\\', '/') != stop && dir.existsSync() && dir.listSync().isEmpty) {
      dir.deleteSync();
      dir = dir.parent;
    }
  } else {
    stderr.writeln('Warning: MainActivity.kt not found at the old location; move it by hand.');
  }

  stdout.writeln('Application id changed: $oldId -> $newId');
  stdout.writeln('Next: flutter clean && flutter pub get');
}
