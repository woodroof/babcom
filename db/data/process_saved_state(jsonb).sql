-- drop function data.process_saved_state(jsonb);

create or replace function data.process_saved_state(in_state jsonb)
returns jsonb
volatile
as
$$
declare
  v_ret_val jsonb := jsonb '[]';

  v_set_visible integer[];
  v_set_invisible integer[];

  v_subscription record;
  v_full_card_function text;
  v_subscription_object_code text;
  v_new_data jsonb;
  v_object jsonb;
  v_list_changes jsonb;
  v_ret_val_element jsonb;
begin
  assert json.is_object_array(in_state);

  if in_state = jsonb '[]' then
    return v_ret_val;
  end if;

  for v_subscription in
  (
    select
      json.get_integer(value, 'id') as id,
      json.get_integer(value, 'client_id') as client_id,
      json.get_integer(value, 'object_id') as object_id,
      json.get_object(value, 'data') as data,
      json.get_array(value, 'list_objects') as list_objects
    from jsonb_array_elements(in_state)
  )
  loop
    v_full_card_function :=
      json.get_string_opt(
        data.get_attribute_value(v_subscription.object_id, 'full_card_function'),
        null);

    if v_full_card_function is not null then
      execute format('select %s($1, $2)', v_full_card_function)
      using v_subscription.object_id, in_object_id;
    end if;

    v_subscription_object_code := data.get_object_code(v_subscription.object_id);

    -- Объект стал невидимым - отправляем специальный diff и вычищаем подписки
    if not json.get_boolean_opt(data.get_attribute_value(v_subscription.object_id, 'is_visible', in_object_id), false) then
      v_ret_val :=
        v_ret_val ||
        jsonb_build_object(
          'object_id',
          v_subscription_object_code,
          'client_id',
          v_subscription.client_id,
          'object',
          jsonb 'null');

      delete from data.client_subscription_objects
      where client_subscription_id = v_subscription.id;

      delete from data.client_subscriptions
      where id = v_subscription.id;

      continue;
    end if;

    v_new_data := data.get_object(v_subscription.object_id, in_object_id, 'full', v_subscription.object_id);

    v_object := null;
    v_list_changes := jsonb '{}';

    -- Сравниваем и при нахождении различий включаем в diff
    if v_new_data != v_subscription.data then
      v_object := v_new_data;
    end if;

    if v_subscription.list_objects != jsonb '[]' then
      declare
        v_list record;
        v_mini_card_function text;
        v_new_list_data jsonb;
        v_add jsonb;
        v_position_object_id integer;
      begin
        for v_list in
        (
          select
            json.get_integer(value, 'id') as id,
            json.get_integer(value, 'object_id') as object_id,
            json.get_boolean(value, 'is_visible') as is_visible,
            json.get_integer(value, 'index') as index,
            json.get_object_opt(value, 'data', null) as data
          from jsonb_array_elements(v_subscription.list_objects)
        )
        loop
          v_mini_card_function :=
            json.get_string_opt(
              data.get_attribute_value(v_list.object_id, 'mini_card_function'),
              null);

          if v_mini_card_function is not null then
            execute format('select %s($1, $2)', v_mini_card_function)
            using v_list.object_id, in_object_id;
          end if;

          if not json.get_boolean_opt(data.get_attribute_value(v_list.object_id, 'is_visible', in_object_id), false) then
            if v_list.is_visible then
              v_set_invisible := array_append(v_set_invisible, v_list.id);

              v_ret_val :=
                v_ret_val ||
                jsonb_build_object(
                  'object_id',
                  v_subscription_object_code,
                  'client_id',
                  v_subscription.client_id,
                  'list_changes',
                  jsonb_build_object('remove', jsonb_build_array(data.get_object_code(v_list.object_id))));
            end if;
          else
            v_new_list_data := data.get_object(v_list.object_id, in_object_id, 'mini', v_subscription.object_id);

            if not v_list.is_visible or v_new_list_data != v_list.data then
              if not v_list.is_visible then
                v_set_visible := array_append(v_set_visible, v_list.id);

                v_add := jsonb_build_object('object', v_new_list_data);

                select s.value
                into v_position_object_id
                from (
                  select first_value(object_id) over(order by index) as value
                  from data.client_subscription_objects
                  where
                    client_subscription_id = v_subscription.id and
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
                    v_subscription.client_id,
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
                    v_subscription.client_id,
                    'list_changes',
                    jsonb_build_object('change', jsonb_build_array(v_new_list_data)));
              end if;
            end if;
          end if;
        end loop;
      end;
    end if;

    if v_object is not null or v_list_changes != jsonb '{}' then
      v_ret_val_element := jsonb_build_object('object_id', v_subscription_object_code, 'client_id', v_subscription.client_id);

      if v_object is not null then
      v_ret_val_element := v_ret_val_element || jsonb_build_object('object', v_object);
      end if;

      if v_list_changes!= jsonb '{}' then
        v_ret_val_element := v_ret_val_element || jsonb_build_object('list_changes', v_list_changes);
      end if;

      v_ret_val := v_ret_val || v_ret_val_element;
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
