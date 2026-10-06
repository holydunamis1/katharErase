import 'dart:async';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Connects to a running debug app's VM service, pauses each isolate,
/// prints its Dart stack (with file:line), resumes it, and repeats once
/// a few seconds later so a busy loop can be told apart from one long call.
Future<void> main(List<String> args) async {
  final service = await vmServiceConnectUri(args[0]);
  for (var sample = 1; sample <= 2; sample++) {
    print('##### SAMPLE $sample');
    final vm = await service.getVM();
    for (final ref in vm.isolates ?? <IsolateRef>[]) {
      final id = ref.id!;
      try {
        await service.pause(id);
        await Future<void>.delayed(const Duration(seconds: 2));
        final iso = await service.getIsolate(id);
        final stack = await service.getStack(id);
        print('ISOLATE ${iso.name} pauseEvent=${iso.pauseEvent?.kind}');
        for (final f in (stack.frames ?? <Frame>[]).take(30)) {
          var where = f.location?.script?.uri ?? '';
          final tok = f.location?.tokenPos;
          final scriptId = f.location?.script?.id;
          if (tok != null && scriptId != null) {
            try {
              final script = await service.getObject(id, scriptId) as Script;
              where = '$where:${script.getLineNumberFromTokenPos(tok)}';
            } catch (_) {}
          }
          print('  #${f.index} ${f.function?.name ?? f.code?.name} $where');
        }
        await service.resume(id);
      } catch (e) {
        print('ISOLATE ${ref.name}: could not sample ($e)');
      }
    }
    if (sample == 1) await Future<void>.delayed(const Duration(seconds: 5));
  }
  await service.dispose();
}
