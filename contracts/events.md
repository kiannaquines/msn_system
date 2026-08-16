# Realtime event contract

All channels are private. A FastAPI access token is passed to Supabase Realtime before subscribing.

## Topics

- `delivery:{delivery_uuid}:location`
- `delivery:{delivery_uuid}:status`

## Events

### `location.updated`

```json
{
  "delivery_id": "uuid",
  "latitude": 7.106,
  "longitude": 124.829,
  "accuracy_meters": 8.4,
  "recorded_at": "2026-08-16T10:00:00Z",
  "eta_minutes": 12
}
```

### `delivery.status_changed`

```json
{
  "delivery_id": "uuid",
  "order_id": "uuid",
  "previous_status": "assigned",
  "status": "picked_up",
  "changed_at": "2026-08-16T10:02:00Z"
}
```

### `delivery.eta_updated`

Contains `delivery_id`, `eta_minutes`, `distance_meters`, and `calculated_at`.

### `delivery.completed` and `delivery.cancelled`

Contain `delivery_id`, `order_id`, and `changed_at`. Clients must fetch the REST snapshot after receiving either event.

## Resynchronization

Realtime events are hints, not the system of record. After reconnecting, clients fetch `GET /api/v1/deliveries/{delivery_id}`. If Realtime is unavailable, active tracking polls this endpoint every 5-10 seconds.

