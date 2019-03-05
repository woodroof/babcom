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
  v_object_code text;
  v_data jsonb;
  v_ignore boolean;
begin
  if in_subsciptions_ids is null then
    return v_state;
  end if;

  v_content_attr_id := data.get_attribute_id('content');

  for v_client in
  (
    select
      cs.client_id,
      array_agg(array[cs.id, cs.object_id]) client_subscriptions,
      array_agg(o.code) client_object_codes,
      array_agg(cs.data) client_datas
    from data.client_subscriptions cs
    join data.objects o on
      o.id = cs.object_id
    where cs.id = any(in_subsciptions_ids)
    group by client_id
  )
  loop
    v_actor_id := data.get_active_actor_id(v_client.client_id);

    v_length := array_length(v_client.client_subscriptions, 1);
    for i in 1..v_length loop
      v_id := v_client.client_subscriptions[i][1];
      v_object_id := v_client.client_subscriptions[i][2];
      v_object_code := v_client.client_object_codes[i];
      v_data := v_client.client_datas[i];
      v_ignore := json.get_boolean_opt(data.get_attribute_value(v_object_id, in_ignore_list_elements_attr_id), false);

      if not v_ignore then
        select
          jsonb_agg(
            jsonb_build_object(
              'id',
              cso.id,
              'object_id',
              cso.object_id,
              'object_code',
              o.code,
              'index',
              cso.index,
              'data',
              cso.data))
        into v_list_objects
        from data.client_subscription_objects cso
        join data.objects o on
          o.id = cso.object_id
        where
          cso.client_subscription_id = v_id and
          cso.object_id not in (
            select value
            from unnest(in_filtered_list_object_ids) a(value));

        if v_list_objects is null then
          v_list_objects := jsonb '[]';
        end if;
      else
        v_list_objects := jsonb '[]';
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
          'object_code',
          v_object_code,
          'data',
          v_data,
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
