import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:omoji/build_config.dart';
import 'package:omoji/services/logger_service.dart';
import 'package:omoji/services/private_file_permissions.dart';

class UpdateCheckService {
  static const Duration _checkInterval = Duration(hours: 24);
  // The latest published GitHub release's tag is the canonical app version.
  static const String _githubReleasesApi =
      'https://api.github.com/repos/Aeroclipse-Proprietary-Limited/Omoji/releases/latest';

  static final ValueNotifier<bool> updateAvailable = ValueNotifier(false);
  static final ValueNotifier<String?> latestVersion = ValueNotifier(null);

  static File get _cacheFile {
    final home = Platform.environment['HOME'] ?? '';
    return File('$home/.config/omoji/update-check.json');
  }

  static Future<void> checkIfDue({bool force = false}) async {
    final cached = await _readCache();
    if (cached != null) {
      _publish(cached.version);
      final elapsed = DateTime.now().difference(cached.checkedAt);
      if (!force && elapsed >= Duration.zero && elapsed < _checkInterval) {
        return;
      }
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final version = await _fetchGitHubVersion(client);
      if (version == null) return;

      _publish(version);
      await _writeCache(
        _CachedUpdate(version: version, checkedAt: DateTime.now()),
      );
    } finally {
      client.close(force: true);
    }
  }

  static bool isVersionNewer(String candidate, String current) {
    final candidateParts = _versionParts(candidate);
    final currentParts = _versionParts(current);
    if (candidateParts == null || currentParts == null) return false;

    for (var i = 0; i < candidateParts.length; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      if (candidateParts[i] != currentPart) {
        return candidateParts[i] > currentPart;
      }
    }
    return false;
  }

  static List<int>? _versionParts(String version) {
    final normalized = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final core = normalized.split(RegExp(r'[+-]')).first;
    final parts = core.split('.');
    if (parts.isEmpty || parts.any((part) => int.tryParse(part) == null)) {
      return null;
    }
    return parts.map(int.parse).toList();
  }

  static void _publish(String version) {
    latestVersion.value = version;
    updateAvailable.value = isVersionNewer(version, omojiVersion);
  }

  static Future<String?> _fetchGitHubVersion(HttpClient client) async {
    try {
      final json = await _getJson(
        client,
        Uri.parse(_githubReleasesApi),
        headers: {'Accept': 'application/vnd.github+json'},
      );
      if (json is Map<String, dynamic> && json['tag_name'] is String) {
        final tag = (json['tag_name'] as String).trim();
        if (_versionParts(tag) != null) return tag;
      }
      throw const FormatException('GitHub response has no valid release tag.');
    } on IOException catch (error, stackTrace) {
      await LoggerService.warn(
        'GitHub update check failed: $error\n$stackTrace',
      );
    } on TimeoutException catch (error, stackTrace) {
      await LoggerService.warn(
        'GitHub update check failed: $error\n$stackTrace',
      );
    } on FormatException catch (error, stackTrace) {
      await LoggerService.warn(
        'GitHub update check failed: $error\n$stackTrace',
      );
    }
    return null;
  }

  static Future<dynamic> _getJson(
    HttpClient client,
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 8));
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Update service returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 8));
    return jsonDecode(body);
  }

  static Future<_CachedUpdate?> _readCache() async {
    try {
      final file = _cacheFile;
      if (!await file.exists()) return null;
      await PrivateFilePermissions.secureDirectory(file.parent);
      await PrivateFilePermissions.secureFile(file);
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] is! String ||
          decoded['checkedAt'] is! int) {
        throw const FormatException('Update-check cache has an invalid shape.');
      }
      return _CachedUpdate(
        version: decoded['version'] as String,
        checkedAt: DateTime.fromMillisecondsSinceEpoch(
          decoded['checkedAt'] as int,
        ),
      );
    } on FileSystemException catch (error, stackTrace) {
      await LoggerService.warn(
        'Could not read update-check cache: $error\n$stackTrace',
      );
    } on FormatException catch (error, stackTrace) {
      await LoggerService.warn(
        'Could not read update-check cache: $error\n$stackTrace',
      );
    }
    return null;
  }

  static Future<void> _writeCache(_CachedUpdate cache) async {
    try {
      final file = _cacheFile;
      await PrivateFilePermissions.secureDirectory(file.parent);
      await file.writeAsString(
        jsonEncode({
          'version': cache.version,
          'checkedAt': cache.checkedAt.millisecondsSinceEpoch,
        }),
        flush: true,
      );
      await PrivateFilePermissions.secureFile(file);
    } on FileSystemException catch (error, stackTrace) {
      await LoggerService.warn(
        'Could not save update-check cache: $error\n$stackTrace',
      );
    }
  }
}

class _CachedUpdate {
  final String version;
  final DateTime checkedAt;

  const _CachedUpdate({required this.version, required this.checkedAt});
}
