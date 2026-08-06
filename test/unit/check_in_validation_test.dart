import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/constants/app_strings.dart';
import 'package:gelatino/models/gelato_type.dart';
import 'package:gelatino/utils/check_in_validation.dart';

void main() {
  test('requires a gelato type before submission', () {
    expect(validateGelatoType(null), AppStrings.checkInErrorNoGelatoType);
    expect(validateGelatoType(defaultGelatoTypes.first), isNull);
  });
}
