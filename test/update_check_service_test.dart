import 'package:flutter_test/flutter_test.dart';
import 'package:omoji/services/update_check_service.dart';

void main() {
  group('UpdateCheckService.isVersionNewer', () {
    test('compares numeric release components', () {
      expect(UpdateCheckService.isVersionNewer('1.2.6', '1.2.5'), isTrue);
      expect(UpdateCheckService.isVersionNewer('1.10.0', '1.9.9'), isTrue);
      expect(UpdateCheckService.isVersionNewer('1.2.5', '1.2.6'), isFalse);
    });

    test('normalizes tags and ignores build metadata', () {
      expect(UpdateCheckService.isVersionNewer('v1.2.6', '1.2.5+18'), isTrue);
      expect(UpdateCheckService.isVersionNewer('1.2.6+1', '1.2.6+2'), isFalse);
    });

    test('does not compare malformed versions as newer', () {
      expect(UpdateCheckService.isVersionNewer('latest', '1.2.5'), isFalse);
      expect(UpdateCheckService.isVersionNewer('1.x.0', '1.2.5'), isFalse);
    });
  });
}
