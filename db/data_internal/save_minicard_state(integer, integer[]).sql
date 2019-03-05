-- drop function data_internal.save_minicard_state(integer, integer[]);

create or replace function data_internal.save_minicard_state(in_object_id integer, in_filtered_parent_object_ids integer[] default null::integer[])
returns jsonb
volatile
as
$$
declare
  v_state jsonb;
begin
  select
    jsonb_agg(
      jsonb_build_object(
        'id',
        cso.id,
        'client_id',
        cs.client_id,
        'actor_id',
        data.get_active_actor_id(cs.client_id),
        'object_id',
        cs.object_id,
        'object_code',
        o.code,
        'data',
        cso.data,
        'index',
        cso.index))
  into v_state
  from data.client_subscription_objects cso
  join data.client_subscriptions cs
    on cs.id = cso.client_subscription_id
    and cs.object_id not in (select value from unnest(in_filtered_parent_object_ids) a(value))
  join data.objects o
    on o.id = cs.object_id
  where cso.object_id = in_object_id;

  return coalesce(v_state, jsonb '[]');
end;
$$
language plpgsql;
