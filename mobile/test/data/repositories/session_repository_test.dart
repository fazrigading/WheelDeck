import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:wheeldeck/data/repositories/session_repository.dart';
import 'package:wheeldeck/network/pairing.dart';
import 'package:wheeldeck/network/wheeldeck_client.dart';

class _MemoryStore implements SessionTokenStore {
  String? token;

  @override
  Future<String?> load() async => token;

  @override
  Future<void> save(String value) async => token = value;
}

void main() {
  group('SessionRepository', () {
    test('restoreSession returns the stored token', () async {
      final channel = StreamChannelController<dynamic>(sync: true);
      channel.foreign.stream.listen((_) {});
      final store = _MemoryStore()..token = 'persisted-token';
      final client = WheelDeckClient(
        deviceId: 'phone-1',
        connect: (uri) async => channel.local,
      );
      final repository = SessionRepository(
        pairing: PairingController(store: store, client: client),
      );

      expect(await repository.restoreSession(), 'persisted-token');

      await channel.local.sink.close();
    });
  });
}
