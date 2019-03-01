-- drop function data_internal.save_minicard_state(integer, integer[]);

create or replace function data_internal.save_minicard_state(in_object_id integer, in_filtered_parent_object_ids integer[] default null::integer[])
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_state jsonb := jsonb '[]';

  v_list record;
  v_actor_id integer;
  v_subscription_object jsonb;
begin
  for v_list in
  (
    select
      cso.id,
      cs.client_id,
      cs.object_id,
      cso.is_visible,
      cso.index
    from data.client_subscription_objects cso
    join data.client_subscriptions cs
      on cs.id = cso.client_subscription_id
      and cs.object_id not in (select value from unnest(in_filtered_parent_object_ids) a(value))
    where cso.object_id = in_object_id
  )
  loop
    v_actor_id := data.get_active_actor_id(v_list.client_id);

    v_subscription_object :=
      jsonb_build_object(
        'id',
        v_list.id,
        'client_id',
        v_list.client_id,
        'actor_id',
        v_actor_id,
        'object_id',
        v_list.object_id,
        'object_code',
        v_object_code,
        'is_visible',
        v_list.is_visible,
        'index',
        v_list.index);

    if v_list.is_visible then
      -- Изменения невидимых объектов должны были пройти через change_object, атрибут в таблице client_subscription_objects был бы изменён
      assert json.get_boolean(data.get_attribute_value(in_object_id, 'is_visible', v_actor_id));

      v_subscription_object :=
        v_subscription_object ||
          jsonb_build_object('data', data.get_object(in_object_id, v_actor_id, 'mini', v_list.object_id));
    end if;

    v_state := v_state || v_subscription_object;
  end loop;

  return v_state;
end;
$$
language plpgsql;
