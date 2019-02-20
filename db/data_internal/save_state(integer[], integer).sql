-- drop function data_internal.save_state(integer[], integer);

create or replace function data_internal.save_state(in_subsciptions_ids integer[], in_filtered_list_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_state jsonb := jsonb '[]';
  v_subscription record;
  v_actor_id integer;
  v_list_objects jsonb;
  v_list record;
  v_list_object jsonb;
begin
  if in_subsciptions_ids is null then
    return v_state;
  end if;

  for v_subscription in
  (
    select
      id,
      object_id,
      client_id
    from data.client_subscriptions
    where id = any(in_subsciptions_ids)
  )
  loop
    v_actor_id := data.get_active_actor_id(v_subscription.client_id);

    v_list_objects := jsonb '[]';

    for v_list in
    (
      select
        id,
        object_id,
        is_visible,
        index
      from data.client_subscription_objects
      where
        client_subscription_id = v_subscription.id and
        (in_filtered_list_object_id is null or object_id != in_filtered_list_object_id)
    )
    loop
      v_list_object :=
        jsonb_build_object(
          'id',
          v_list.id,
          'object_id',
          v_list.object_id,
          'is_visible',
          v_list.is_visible,
          'index',
          v_list.index);

      if v_list.is_visible then
        v_list_object :=
          v_list_object ||
            jsonb_build_object(
              'data',
              data.get_object(v_list.object_id, v_actor_id, 'mini', v_subscription.object_id));
      end if;

      v_list_objects := v_list_objects || v_list_object;
    end loop;

    v_state :=
      v_state ||
      jsonb_build_object(
        'id',
        v_subscription.id,
        'client_id',
        v_subscription.client_id,
        'object_id',
        v_subscription.object_id,
        'data',
        data.get_object(v_subscription.object_id, v_actor_id, 'full', v_subscription.object_id),
        'list_objects',
        v_list_objects);
  end loop;

  return v_state;
end;
$$
language plpgsql;
