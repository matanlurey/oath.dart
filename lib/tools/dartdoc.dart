import 'dart:convert';
import 'dart:io' as io;

import 'package:oath/src/tool.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// The mode to run `dartdoc` in.
enum DartdocMode {
  /// Generates the documentation in `doc/api`.
  generate,

  /// Generates the documentation in a temporary directory and serves it.
  preview;
}

/// Runs the `dartdoc` tool with the given options.
///
/// - [command]: The command to run. Defaults to `['dart', 'doc']`.
/// - [mode]: The mode to run `dartdoc` in. Defaults to [DartdocMode.generate].
/// - [tools]: The toolbox to use instead of the default one.
/// - [port]: The port to serve the documentation n. Defaults to a random port.
/// - [browse]: Whether to open the generated documentation in the browser.
Future<void> runDartdoc({
  required bool preview,
  required bool generate,
  List<String> command = const ['dart', 'doc'],
  Toolbox? tools,
  int? port,
  bool browse = false,
  String? outDir,
}) async {
  return runTool((tools) async {
    io.Directory? outputDir;
    if (outDir != null) {
      outputDir = io.Directory(outDir);
    } else if (preview) {
      outputDir = await tools.getTempDir('dartdoc');
    }
    if (generate) {
      final [name, ...args] = command;
      final dartdoc = await io.Process.start(
        name,
        [
          ...args,
          if (outputDir != null) '--output=${outputDir.path}',
        ],
      );
      tools.addCleanupTask(dartdoc.kill);

      dartdoc.stdout.transform(const Utf8Decoder()).listen(tools.stdout.write);
      dartdoc.stderr.transform(const Utf8Decoder()).listen(tools.stderr.write);

      final exitCode = await dartdoc.exitCode;
      if (exitCode != 0) {
        throw io.ProcessException(
          name,
          args,
          'Failed with exit code $exitCode.',
        );
      }
    }
    if (preview) {
      outputDir!;
      final handler = createStaticHandler(
        outputDir.path,
        defaultDocument: 'index.html',
      );
      final server = await shelf_io.serve(handler, 'localhost', port ?? 0);
      tools.addCleanupTask(server.close);

      final url = Uri.http('localhost:${server.port}', '/');
      tools.stdout.writeln('Serving documentation at $url');

      if (browse) {
        await tools.browse(url);
      }

      await tools.forever();
    }
  });
}
