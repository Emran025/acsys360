import '../lib/arabic_compiler.dart';

void main() {
  final valid = Compiler().compile('''برنامج اختبار {
    متغير س: صحيح;
    س = 2 + 3;
    اطبع(س);
}.''');
  assert(valid.success);
  assert(valid.threeAddressCode.isNotEmpty);
  assert(valid.semantic?.symbols.containsKey('س') == true);

  final invalid = Compiler().compile('''برنامج خطأ {
    متغير س: صحيح;
    ص = 1;
}.''');
  assert(!invalid.success);
  assert(invalid.diagnostics.any((item) => item.phase == 'semantic'));
  print('Self-tests passed');
}
