import 'package:flutter_test/flutter_test.dart';
import 'package:mns_rider/src/data/offline_event_queue.dart';

void main() {
  test('memory queue preserves order and ignores duplicate event IDs', () async {
    final queue = MemoryOfflineEventQueue();
    final first = QueuedEvent(
      id: 'event-1',
      deliveryId: 'delivery-1',
      type: QueuedEventType.location,
      payload: const {'latitude': 14.5, 'longitude': 121.0},
      createdAt: DateTime.utc(2026),
    );
    final second = QueuedEvent(
      id: 'event-2',
      deliveryId: 'delivery-1',
      type: QueuedEventType.status,
      payload: const {'status': 'picked_up'},
      createdAt: DateTime.utc(2026, 1, 1, 0, 0, 10),
    );

    await queue.enqueue(first);
    await queue.enqueue(first);
    await queue.enqueue(second);

    expect(await queue.count(), 2);
    expect((await queue.pending()).map((event) => event.id), [
      'event-1',
      'event-2',
    ]);
  });

  test('removing an acknowledged event leaves remaining events', () async {
    final queue = MemoryOfflineEventQueue();
    for (final id in ['one', 'two']) {
      await queue.enqueue(QueuedEvent(
        id: id,
        deliveryId: 'delivery-1',
        type: QueuedEventType.cashCollection,
        payload: const {},
        createdAt: DateTime.utc(2026),
      ));
    }

    await queue.remove('one');

    expect(await queue.count(), 1);
    expect((await queue.pending()).single.id, 'two');
  });
}
