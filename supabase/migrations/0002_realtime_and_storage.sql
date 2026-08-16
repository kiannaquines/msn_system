-- Run after Alembic revision 0001. FastAPI is the only write boundary.
create extension if not exists pgcrypto;

create or replace function app.broadcast_location_change()
returns trigger
security definer
set search_path = ''
language plpgsql
as $$
begin
  perform realtime.broadcast_changes(
    'delivery:' || new.order_id::text || ':location',
    'location.updated',
    tg_op,
    tg_table_name,
    tg_table_schema,
    new,
    old
  );
  return new;
end;
$$;

drop trigger if exists location_realtime_broadcast on app.location_points;
create trigger location_realtime_broadcast
after insert on app.location_points
for each row execute function app.broadcast_location_change();

create or replace function app.broadcast_delivery_status_change()
returns trigger
security definer
set search_path = ''
language plpgsql
as $$
begin
  perform realtime.broadcast_changes(
    'delivery:' || new.order_id::text || ':status',
    'delivery.status_changed',
    tg_op,
    tg_table_name,
    tg_table_schema,
    new,
    old
  );
  return new;
end;
$$;

drop trigger if exists delivery_status_realtime_broadcast on app.delivery_events;
create trigger delivery_status_realtime_broadcast
after insert on app.delivery_events
for each row execute function app.broadcast_delivery_status_change();

-- Custom FastAPI JWTs provide sub and role. Users can only receive private
-- delivery topics associated with their order/assignment; clients cannot send.
create policy "authorized delivery subscriptions"
on realtime.messages
for select
to authenticated
using (
  exists (
    select 1
    from app.orders o
    join app.users u on u.id = (auth.jwt() ->> 'sub')
    where (
      realtime.topic() = 'delivery:' || o.id::text || ':location'
      or realtime.topic() = 'delivery:' || o.id::text || ':status'
    )
    and u.is_active
    and (
      (u.role = 'customer' and o.customer_id = u.id)
      or (u.role = 'rider' and o.rider_id = u.id)
      or u.role = 'admin'
    )
  )
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('menu-images', 'menu-images', true, 5000000, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Uploads use signed URLs created by FastAPI's server-side Supabase secret.
-- No browser insert/update/delete policy is granted.
create policy "public menu image reads"
on storage.objects for select
to public
using (bucket_id = 'menu-images');

