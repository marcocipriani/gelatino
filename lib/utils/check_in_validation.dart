import '../constants/app_strings.dart';
import '../models/gelato_type.dart';

String? validateGelatoType(GelatoType? type) {
  return type == null ? AppStrings.checkInErrorNoGelatoType : null;
}
