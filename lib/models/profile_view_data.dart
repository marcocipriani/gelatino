abstract interface class ProfileViewData {
  String get uid;
  String get displayName;
  String? get photoUrl;
  String? get favoriteGelateria;
  String? get favoriteFlavor;
  List<String> get favoriteFlavors;
  List<String> get favoriteFlavorIds;
  int get points;
}
