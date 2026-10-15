/// Return only to local service routes; never nest an entry gate or leave the app.
String? entryReturnLocation(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('//') ||
      uri.path.contains(r'\') ||
      uri.path == '/explore' ||
      uri.path.startsWith('/explore/') ||
      const ['/auth-loading', '/login', '/login/email'].contains(uri.path)) {
    return null;
  }
  if (uri.path == '/onboarding' &&
      uri.queryParameters['verify'] != 'true' &&
      uri.queryParameters['edit'] != 'true') {
    return null;
  }
  return uri.toString();
}

String withEntryReturn(String location, String? returnTo) {
  final safe = entryReturnLocation(returnTo);
  if (safe == null || safe == '/') return location;
  final uri = Uri.parse(location);
  return uri
      .replace(queryParameters: {...uri.queryParameters, 'from': safe})
      .toString();
}
