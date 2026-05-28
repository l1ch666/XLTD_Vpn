// Smoke test placeholder. The full app boots a VPN bridge that doesn't run in
// the headless test environment, so we just verify the URI parser compiles.

import 'package:flutter_test/flutter_test.dart';

import 'package:xltd_vpn/services/uri_parser.dart';

void main() {
  test('URI parser accepts a canonical olcrtc:// link', () {
    const link =
        'olcrtc://jitsi?datachannel@meet.jit.si/example#'
        '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
    final cfg = UriParser.parse(link);
    expect(cfg.carrier, 'jitsi');
    expect(cfg.transport, 'datachannel');
  });
}
