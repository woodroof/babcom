-- drop function data_internal.process_saved_minicard_state(integer, jsonb);

create or replace function data_internal.process_saved_minicard_state(in_object_id integer, in_state jsonb)
returns jsonb
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_ret_val jsonb := jsonb '[]';

  v_mini_card_function text := json.get_string_opt(data.get_attribute_value(in_object_id, 'mini_card_function'), null);
  v_list record;
  v_new_data jsonb;
  v_attributes jsonb;
  v_actions jsonb;
  v_position_object_id integer;
  v_add jsonb;
  v_subscription_object_code text;

  v_set_visible integer[];
  v_set_invisible integer[];
begin
  assert json.is_object_array(in_state);

  if in_state = jsonb '[]' then
    return v_ret_val;
  end if;

  for v_list in
  (
    select
      json.get_integer(value, 'id') as id,
      json.get_integer(value, 'client_id') as client_id,
      json.get_integer(value, 'actor_id') as actor_id,
      json.get_integer(value, 'object_id') as object_id,
      json.get_boolean(value, 'is_visible') as is_visible,
      json.get_integer(value, 'index') as index,
      json.get_object_opt(value, 'data', null) as data
    from jsonb_array_elements(in_state)
  )
  loop
    if v_mini_card_function is not null then
      execute format('select %s($1, $2)', v_mini_card_function)
      using in_object_id, v_list.actor_id;
    end if;

    if not json.get_boolean_opt(data.get_attribute_value(in_object_id, 'is_visible', v_list.actor_id), false) then
      if v_list.is_visible then
        v_set_invisible := array_append(v_set_invisible, v_list.id);

        v_ret_val :=
          v_ret_val ||
          jsonb_build_object(
            'object_id',
            data.get_object_code(v_list.object_id),
            'client_id',
            v_list.client_id,
            'list_changes',
            jsonb_build_object('remove', jsonb_build_array(v_object_code)));
      end if;
    else
      v_new_data := data.get_object(in_object_id, v_list.actor_id, 'mini', v_list.object_id);

      if not v_list.is_visible or v_new_data != v_list.data then
        v_subscription_object_code := data.get_object_code(v_list.object_id);

        if not v_list.is_visible then
          v_set_visible := array_append(v_set_visible, v_list.id);

          v_add := jsonb_build_object('object', v_new_data);

          select s.value
          into v_position_object_id
          from (
            select first_value(object_id) over(order by index) as value
            from data.client_subscription_objects
            where
              client_subscription_id in (
                select client_subscription_id
                from data.client_subscription_objects
                where id = v_list.id) and
              index > v_list.index and
              is_visible is true
          ) s
          limit 1;

          if v_position_object_id is not null then
            v_add := v_add || jsonb_build_object('position', data.get_object_code(v_position_object_id));
          end if;

          v_ret_val :=
            v_ret_val ||
            jsonb_build_object(
              'object_id',
              v_subscription_object_code,
              'client_id',
              v_list.client_id,
              'list_changes',
              jsonb_build_object(
                'add',
                jsonb_build_array(v_add)));
        else
          v_ret_val :=
            v_ret_val ||
            jsonb_build_object(
              'object_id',
              v_subscription_object_code,
              'client_id',
              v_list.client_id,
              'list_changes',
              jsonb_build_object('change', jsonb_build_array(v_new_data)));
        end if;
      end if;
    end if;
  end loop;

  if v_set_visible is not null then
    update data.client_subscription_objects
    set is_visible = true
    where id = any(v_set_visible);
  end if;

  if v_set_invisible is not null then
    update data.client_subscription_objects
    set is_visible = false
    where id = any(v_set_invisible);
  end if;

  return v_ret_val;
end;
$$
language plpgsql;
