import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const incomingShareChannel = MethodChannel('mobile_seo/incoming_share');

Future<void> notifyIncomingShare() {
  final done = Completer<void>();
  TestWidgetsFlutterBinding.ensureInitialized().channelBuffers.push(
    incomingShareChannel.name,
    const StandardMethodCodec().encodeMethodCall(
      const MethodCall('shareAvailable'),
    ),
    (data) {
      try {
        if (data != null) const StandardMethodCodec().decodeEnvelope(data);
        done.complete();
      } catch (error, stack) {
        done.completeError(error, stack);
      }
    },
  );
  return done.future;
}

class ShareInbox {
  ShareInbox([List<String> initial = const []]) : pending = [...initial] {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(incomingShareChannel, (call) async {
      expect(call.method, 'takePendingShares');
      final result = [...pending];
      pending.clear();
      return result;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(incomingShareChannel, null),
    );
  }

  final List<String> pending;

  Future<void> send(String text) async {
    pending.add(text);
    await notifyIncomingShare();
  }
}
