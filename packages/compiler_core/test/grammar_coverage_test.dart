import 'package:compiler_core/arabic_compiler.dart';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('parses the formal declaration and control-flow grammar', () {
    final result = _parse('''
برنامج متقدم؛ {
ثابت حد = 3;
نوع درجات = قائمة[3] من صحيح;
نوع طالب = سجل { رقم: صحيح; اسم: خيط_رمزي; };
متغير س: صحيح;
متغير قائمة_درجات: درجات;
اجراء زد(بالمرجع س: صحيح); {
  س = س + 1;
};
س = 0;
كرر(س = 1 الى حد اضف 1) {
  اطبع(س);
}
طالما(س < حد) استمر {
  س = س + 1;
}
اعد {
  س = س - 1;
} حتى(س == 0)
}.
''');

    expect(result.diagnostics, isEmpty);
    expect(result.program, isNotNull);
    expect(result.program!.declarations, hasLength(6));
    expect(result.program!.statements, hasLength(4));
  });

  test('emits TAC, assembly, and rich symbol kinds from valid source', () {
    final result = _parse('''
برنامج مخرجات؛ {
ثابت الحد = 2;
متغير عداد: صحيح;
اجراء اطبع_الحد(بالقيمة قيمة: صحيح); {
  اطبع(قيمة);
};
عداد = الحد + 1;
اطبع(عداد);
اطبع_الحد(عداد);
}.
''');

    expect(result.success, isTrue);
    expect(result.threeAddressCode, contains('entry:'));
    expect(result.assembly, contains('section .text'));
    expect(result.assembly, contains('arabic_print'));
    expect(result.semantic!.symbols['الحد']!.kind, 'constant');
    expect(result.semantic!.symbols['اطبع_الحد']!.kind, 'procedure');
  });

  test('executes valid control flow and returns real output', () {
    final result = _parse('''
برنامج تشغيل؛ {
متغير س: صحيح;
س = 1;
طالما(س < 4) استمر {
  اطبع(س);
  س = س + 1;
}
}.
''');

    expect(result.success, isTrue);
    expect(result.executionOutput, ['1', '2', '3']);
  });

  test('reports type and access errors from the semantic phase', () {
    final result = _parse('''
برنامج أخطاء؛ {
متغير رقم: صحيح;
متغير حالة: منطقي;
رقم = صح;
اذا(رقم) فان { حالة = 1; }
اطبع(غير_معرف);
}.
''');

    expect(result.diagnostics, isNotEmpty);
    expect(
      result.diagnostics.map((diagnostic) => diagnostic.phase),
      everyElement('semantic'),
    );
  });

  test('rejects reserved instructions where a type name is required', () {
    final result = _parse('''
برنامج نوع_خاطئ؛ {
متغير س: اطبع;
}.
''');

    expect(result.success, isFalse);
    expect(
      result.diagnostics.map((diagnostic) => diagnostic.phase),
      contains('syntax'),
    );
  });

  test('parses the formal else-if separator and executes one branch', () {
    final result = _parse('''
برنامج تفرع؛ {
متغير س: صحيح;
اذا(خطأ) فان { س = 1; }; والا اذا(صح) فان { س = 2; };
اطبع(س);
}.
''');

    expect(result.success, isTrue);
    expect(result.executionOutput, ['2']);
  });

  test('resolves compound aliases for execution and access checks', () {
    final result = _parse('''
برنامج مركب؛ {
نوع درجات = قائمة[2] من صحيح;
نوع طالب = سجل { درجة: درجات; اسم: خيط_رمزي; };
متغير الطالب: طالب;
الطالب.درجة[0] = 7;
الطالب.اسم = "علي";
اطبع(الطالب.درجة[0], الطالب.اسم);
}.
''');

    expect(result.success, isTrue);
    expect(result.executionOutput, ['7 علي']);
  });

  test(
    'executes repeat ranges in both directions and emits correct TAC guard',
    () {
      final result = _parse('''
برنامج تكرار؛ {
متغير س: صحيح;
كرر(س = 1 الى 3 اضف 1) { اطبع(س); }
كرر(س = 3 الى 1 اضف -1) { اطبع(س); }
}.
''');

      expect(result.success, isTrue);
      expect(result.executionOutput, ['1', '2', '3', '3', '2', '1']);
      expect(result.threeAddressCode, contains(contains('<= 3')));
    },
  );

  test(
    'reports runtime failures instead of claiming successful compilation',
    () {
      final result = _parse(r'''
برنامج خطأ_تنفيذ؛ {
متغير س: صحيح;
س = 1 \ 0;
اطبع(س);
}.
''');

      expect(result.success, isFalse);
      expect(
        result.diagnostics.map((diagnostic) => diagnostic.phase),
        contains('execution'),
      );
      expect(result.executionOutput, isEmpty);
    },
  );
  test('compiles every diverse academic example', () {
    final files =
        Directory('../../examples')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.arb'))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    expect(files, hasLength(10));
    for (final file in files) {
      final result = _parse(file.readAsStringSync());
      expect(
        result.success,
        isTrue,
        reason:
            '${file.path}: ${result.diagnostics.map((item) => item.message).join(' | ')}',
      );
    }
  });
}

CompilationResult _parse(String source) => const Compiler().compile(source);
