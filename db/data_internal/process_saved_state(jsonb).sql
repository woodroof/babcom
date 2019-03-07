-- drop function data_internal.process_saved_state(jsonb);

create or replace function data_internal.process_saved_state(in_state jsonb)
returns jsonb
volatile
as
$$
declare
  v_ret_val jsonb := jsonb '[]';

  v_set_invisible integer[];

  v_content_attr_id integer;
  v_full_card_function_attr_id integer;
  v_is_visible_attr_id integer;
  v_subscription record;
  v_full_card_function text;
  v_new_data jsonb;
  v_object jsonb;
  v_new_content jsonb;
  v_remove_list_changes jsonb;
  v_add_list_changes jsonb;
  v_change_list_changes jsonb;
  v_list_changes jsonb;
  v_ret_val_element jsonb;
begin
  if in_state = jsonb '[]' then
    return v_ret_val;
  end if;

  v_content_attr_id := data.get_attribute_id('content');
  v_full_card_function_attr_id := data.get_attribute_id('full_card_function');
  v_is_visible_attr_id := data.get_attribute_id('is_visible');

  for v_subscription in
  (
    select
      cs.id as id,
      cs.client_id,
      cs.object_id,
      o.code object_code,
      json.get_integer(value, 'actor_id') as actor_id,
      cs.data,
      json.get_array_opt(value, 'content', null) as content,
      value->'list_objects' as list_objects
    from jsonb_array_elements(in_state) s
    join data.client_subscriptions cs on
      cs.id = json.get_integer(value, 'id')
    join data.objects o on
      o.id = cs.object_id
  )
  loop
    v_full_card_function :=
      json.get_string_opt(
        data.get_attribute_value(v_subscription.object_id, v_full_card_function_attr_id),
        null);

    if v_full_card_function is not null then
      execute format('select %s($1, $2)', v_full_card_function)
      using v_subscription.object_id, v_subscription.actor_id;
    end if;

    -- Объект стал невидимым - отправляем специальный diff и вычищаем подписки
    if not json.get_boolean_opt(data.get_attribute_value(v_subscription.object_id, v_is_visible_attr_id, v_subscription.actor_id), false) then
      v_ret_val :=
        v_ret_val ||
        jsonb_build_object(
          'object_id',
          v_subscription.object_code,
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

    v_new_data := data.get_object(v_subscription.object_id, v_subscription.actor_id, 'full', v_subscription.object_id);

    v_object := null;
    v_list_changes := jsonb '{}';
    v_remove_list_changes := jsonb '[]';
    v_add_list_changes := jsonb '[]';
    v_change_list_changes := jsonb '[]';

    -- Сравниваем и при нахождении различий включаем в diff
    if v_new_data != v_subscription.data then
      update data.client_subscriptions
      set data = v_new_data
      where id = v_subscription.id;

      v_object := v_new_data;
    end if;

    v_new_content := data.get_attribute_value(v_subscription.object_id, v_content_attr_id, v_subscription.actor_id);

    if v_subscription.content is distinct from v_new_content then
      declare
        v_content_diff jsonb;
        v_add jsonb;
        v_remove jsonb;
      begin

        v_content_diff := data.calc_content_diff(v_subscription.content, v_new_content);

        v_add := json.get_array(v_content_diff, 'add');
        v_remove := json.get_array(v_content_diff, 'remove');

        if v_add != jsonb '[]' or v_remove != jsonb '[]' then
          if v_remove != jsonb '[]' then
            -- Посылаем удаления только для видимых
            select jsonb_agg(a.value)
            into v_remove_list_changes
            from unnest(json.get_string_array(v_remove)) a(value)
            join data.objects o
              on o.code = a.value
            join data.client_subscription_objects cso
              on cso.object_id = o.id
              and cso.client_subscription_id = v_subscription.id
              and cso.data is not null;

            -- А вот удаляем реально все
            delete from data.client_subscription_objects
            where
              client_subscription_id = v_subscription.id and
              object_id in (
                select o.id
                from unnest(json.get_string_array(v_remove)) a(value)
                join data.objects o
                  on o.code = a.value);
          end if;

          if v_add != jsonb '[]' then
            declare
              v_processed_objects jsonb;
              v_add_element record;
              v_object_id integer;
              v_is_visible boolean;
              v_processed_object jsonb;
              v_index integer;
              v_position text;
              v_data jsonb;
              v_add_list_change jsonb;
            begin
              select jsonb_object_agg(o.code, jsonb_build_object('is_visible', cso.data is not null, 'index', cso.index))
              into v_processed_objects
              from data.client_subscription_objects cso
              join data.objects o
                on o.id = cso.object_id
              where cso.client_subscription_id = v_subscription.id;

              for v_add_element in
              (
                select
                  json.get_string(value, 'object_code') as object_code,
                  json.get_string_opt(value, 'position', null) as position
                from jsonb_array_elements(v_add) a(value)
              )
              loop
                -- Если клиенту не возвращался объект, указанный в position,
                -- то этот объект и все дальнейшие обрабатывать не нужно
                if v_add_element.position is not null and (v_processed_objects is null or not v_processed_objects ? v_add_element.position) then
                  exit;
                end if;

                v_object_id := data.get_object_id(v_add_element.object_code);

                v_is_visible :=
                  json.get_boolean_opt(
                    data.get_attribute_value(
                      v_object_id,
                      'is_visible',
                      v_subscription.actor_id),
                    false);

                if v_add_element.position is not null then
                  v_processed_object := json.get_object(v_processed_objects, v_add_element.position);
                  v_index := json.get_integer(v_processed_object, 'index');
                  if json.get_boolean(v_processed_object, 'is_visible') then
                    v_position := v_add_element.position;
                  else
                    select o.code
                    into v_position
                    from data.client_subscription_objects cso
                    join data.objects o
                      on o.id = cso.object_id
                    where
                      cso.client_subscription_id = v_subscription.id and
                      cso.index = (
                        select min(index)
                        from data.client_subscription_objects
                        where
                          client_subscription_id = v_subscription.id and
                          index > v_index and
                          data is not null);
                  end if;

                  update data.client_subscription_objects
                  set index = index + 1
                  where
                    client_subscription_id = v_subscription.id and
                    index >= v_index;
                else
                  select coalesce(max(index) + 1, 1)
                  into v_index
                  from data.client_subscription_objects
                  where
                    client_subscription_id = v_subscription.id;
                end if;

                if v_is_visible then
                  v_data := data.get_object(v_object_id, v_subscription.actor_id, 'mini', v_subscription.object_id);

                  v_add_list_change := jsonb_build_object('object', v_data);
                  if v_position is not null then
                    v_add_list_change := v_add_list_change || jsonb_build_object('position', v_position);
                  end if;
                  v_add_list_changes := v_add_list_changes || v_add_list_change;
                else
                  v_data := null;
                end if;

                insert into data.client_subscription_objects(client_subscription_id, object_id, index, data)
                values(v_subscription.id, data.get_object_id(v_add_element.object_code), v_index, v_data);
              end loop;
            end;
          end if;
        end if;
      end;
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
            cso.id,
            cso.object_id,
            o.code as object_code,
            cso.data,
            cso.index
          from jsonb_array_elements(v_subscription.list_objects) lo
          join data.client_subscription_objects cso on
            cso.id = json.get_integer(value)
          join data.objects o on
            o.id = cso.object_id
          -- Удалённые из content'а мы уже обработали
          where cso.object_id not in (
            select o.id
            from jsonb_array_elements(v_remove_list_changes) e
            join data.objects o on
              o.code = json.get_string(e.value))
        )
        loop
          v_mini_card_function :=
            json.get_string_opt(
              data.get_attribute_value(v_list.object_id, 'mini_card_function'),
              null);

          if v_mini_card_function is not null then
            execute format('select %s($1, $2)', v_mini_card_function)
            using v_list.object_id, v_subscription.actor_id;
          end if;

          if not json.get_boolean_opt(data.get_attribute_value(v_list.object_id, 'is_visible', v_subscription.actor_id), false) then
            if v_list.data != jsonb 'null' then
              v_set_invisible := array_append(v_set_invisible, v_list.id);

              v_remove_list_changes := v_remove_list_changes || v_list.object_code;
            end if;
          else
            v_new_list_data := data.get_object(v_list.object_id, v_subscription.actor_id, 'mini', v_subscription.object_id);

            if v_list.data = jsonb 'null' or v_new_list_data != v_list.data then
              update data.client_subscription_objects
              set data = v_new_list_data
              where id = v_list.id;

              if v_list.data = jsonb 'null' then
                v_add := jsonb_build_object('object', v_new_list_data);

                select s.value
                into v_position_object_id
                from (
                  select first_value(object_id) over(order by index) as value
                  from data.client_subscription_objects
                  where
                    client_subscription_id = v_subscription.id and
                    index > v_list.index and
                    data is not null
                ) s
                limit 1;

                if v_position_object_id is not null then
                  v_add := v_add || jsonb_build_object('position', data.get_object_code(v_position_object_id));
                end if;

                v_add_list_changes := v_add_list_changes || v_add;
              else
                v_change_list_changes := v_change_list_changes || v_new_list_data;
              end if;
            end if;
          end if;
        end loop;
      end;
    end if;

    if v_remove_list_changes != jsonb '[]' then
      v_list_changes := v_list_changes || jsonb_build_object('remove', v_remove_list_changes);
    end if;

    if v_add_list_changes != jsonb '[]' then
      v_list_changes := v_list_changes || jsonb_build_object('add', v_add_list_changes);
    end if;

    if v_change_list_changes != jsonb '[]' then
      v_list_changes := v_list_changes || jsonb_build_object('change', v_change_list_changes);
    end if;

    if v_object is not null or v_list_changes != jsonb '{}' then
      v_ret_val_element := jsonb_build_object('object_id', v_subscription.object_code, 'client_id', v_subscription.client_id);

      if v_object is not null then
      v_ret_val_element := v_ret_val_element || jsonb_build_object('object', v_object);
      end if;

      if v_list_changes != jsonb '{}' then
        v_ret_val_element := v_ret_val_element || jsonb_build_object('list_changes', v_list_changes);
      end if;

      v_ret_val := v_ret_val || v_ret_val_element;
    end if;
  end loop;

  if v_set_invisible is not null then
    update data.client_subscription_objects
    set data = null
    where id = any(v_set_invisible);
  end if;

  return v_ret_val;
end;
$$
language plpgsql;
