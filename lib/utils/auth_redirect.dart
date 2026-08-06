String? safeInternalRedirect(String? rawLocation) {
  if (rawLocation == null || rawLocation.isEmpty || rawLocation.length > 2048) {
    return null;
  }

  var decoded = rawLocation;
  for (var depth = 0; depth < 3; depth++) {
    if (_isDangerousInternalLocation(decoded)) return null;
    try {
      final next = Uri.decodeFull(decoded);
      if (next == decoded) break;
      decoded = next;
    } on Object {
      return null;
    }
  }
  if (_isDangerousInternalLocation(decoded)) return null;

  final location = Uri.tryParse(rawLocation);
  if (location == null ||
      location.hasScheme ||
      location.hasAuthority ||
      !location.path.startsWith('/') ||
      location.path == '/login') {
    return null;
  }
  return location.toString();
}

bool _isDangerousInternalLocation(String value) =>
    value.startsWith('//') ||
    value.contains('\\') ||
    RegExp(r'[\x00-\x1F\x7F]').hasMatch(value);

String? authRedirectFor({required String? uid, required Uri location}) {
  if (uid == null) {
    if (location.path == '/login') return null;
    return Uri(
      path: '/login',
      queryParameters: <String, String>{'redirect': location.toString()},
    ).toString();
  }
  if (location.path != '/login') return null;
  return safeInternalRedirect(location.queryParameters['redirect']) ?? '/';
}
