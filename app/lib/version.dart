class AppVersion {
  static const version = '1.0.0';
  static const build = 1;

  static String get badge => 'v$version';
  static String get full => 'Phiên bản $version (Web PWA)';
}
