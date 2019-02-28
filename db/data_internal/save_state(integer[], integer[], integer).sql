-- drop function data_internal.save_state(integer[], integer[], integer);

create or replace function data_internal.save_state(in_subsciptions_ids integer[], in_filtered_list_object_ids integer[], in_ignore_list_elements_attr_id integer)
returns jsonb
volatile
as
$$
declare
  v_state jsonb := jsonb '[]';
  v_content_attr_id integer;
  v_client record;
  v_actor_id integer;
  v_list_objects jsonb;
  v_list record;
  v_list_object jsonb;
  v_length integer;
  v_id integer;
  v_object_id integer;
  v_ignore boolean;
begin
  if in_subsciptions_ids is null then
    return v_state;
  end if;

  v_content_attr_id := data.get_attribute_id('content');

  for v_client in
  (
    select client_id, array_agg(array[id, object_id]) client_subscriptions
    from data.client_subscriptions
    where id = any(in_subsciptions_ids)
    group by client_id
  )
  loop
    v_actor_id := data.get_active_actor_id(v_client.client_id);

    v_length := array_length(v_client.client_subscriptions, 1);
    for i in 1..v_length loop
      v_list_objects := jsonb '[]';
      v_id := v_client.client_subscriptions[i][1];
      v_object_id := v_client.client_subscriptions[i][2];
      v_ignore := json.get_boolean_opt(data.get_attribute_value(v_object_id, in_ignore_list_elements_attr_id), false);

      if not v_ignore then
        for v_list in
        (
          select
            id,
            object_id,
            is_visible,
            index
          from data.client_subscription_objects
          where
            client_subscription_id = v_id and
            object_id not in (
              select value
              from unnest(in_filtered_list_object_ids) a(value))
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
                  data.get_object(v_list.object_id, v_actor_id, 'mini', v_object_id));
          end if;

          v_list_objects := v_list_objects || v_list_object;
        end loop;
      end if;

      v_state :=
        v_state ||
        jsonb_build_object(
          'id',
          v_id,
          'client_id',
          v_client.client_id,
          'actor_id',
          v_actor_id,
          'object_id',
          v_object_id,
          'data',
          data.get_object(v_object_id, v_actor_id, 'full', v_object_id),
          'content',
          data.get_attribute_value(v_object_id, v_content_attr_id, v_actor_id),
          'list_objects',
          v_list_objects);
    end loop;
  end loop;

  return v_state;
end;
$$
language plpgsql;
