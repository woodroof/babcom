-- drop function data.change_object(integer, jsonb, integer);

create or replace function data.change_object(in_object_id integer, in_changes jsonb, in_actor_id integer default null::integer)
returns jsonb
volatile
as
$$
-- В параметре in_changes приходит массив объектов с полями id, value_object_id, value
-- Если присутствует, value_object_id меняет именно значение, задаваемое для указанного объекта
-- Если value отсутствует (именно отсутствует, а не равно jsonb 'null'!), то указанное значение удаляется, в противном случае - устанавливается

-- Возвращается массив объектов с полями client_id, object и list_changes, поля object и list_changes могут отсутствовать
declare
  v_changes jsonb := data.filter_changes(in_object_id, in_changes);
  v_object_code text;
  v_default_template jsonb;

  v_subscriptions jsonb := jsonb '[]';
  v_subscription_objects jsonb := jsonb '[]';

  v_list_changed boolean := false;

  v_ret_val jsonb := jsonb '[]';
begin
  assert in_actor_id is null or data.is_instance(in_actor_id);

  if v_changes = jsonb '[]' then
    return jsonb '[]';
  end if;

  v_object_code := data.get_object_code(in_object_id);
  v_default_template := data.get_param('template');

  perform *
  from data.objects
  where id = in_object_id
  for update;

  -- Сохраним атрибуты и действия для всех клиентов, подписанных на получение изменений данного объекта
  declare
    v_subscription record;
    v_actor_id integer;
  begin
    for v_subscription in
    (
      select
        id,
        client_id
      from data.client_subscriptions
      where object_id = in_object_id
    )
    loop
      v_actor_id := data.get_active_actor_id(v_subscription.client_id);

      -- Невидимые объекты должны были пройти через change_object, подписки были бы удалены
      assert json.get_boolean(data.get_attribute_value(in_object_id, 'is_visible', v_actor_id));

      v_subscriptions :=
        v_subscriptions ||
        jsonb_build_object(
          'id',
          v_subscription.id,
          'client_id',
          v_subscription.client_id,
          'actor_id',
          v_actor_id,
          'data',
          data.get_object(in_object_id, v_actor_id, 'full', in_object_id));
    end loop;
  end;

  -- Сохраним состояние миникарточек в списках, в которые входит данный объект
  declare
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

      v_subscription_objects := v_subscription_objects || v_subscription_object;
    end loop;
  end;

  -- Меняем состояние объекта
  declare
    v_change record;
    v_content_attribute_id integer := data.get_attribute_id('content');
  begin
    for v_change in
    (
      select
        json.get_integer(value, 'id') as attribute_id,
        json.get_integer_opt(value, 'value_object_id', null) as value_object_id,
        value->'value' as value
      from jsonb_array_elements(v_changes)
    )
    loop
      if v_change.attribute_id = v_content_attribute_id then
        v_list_changed := true;
      end if;

      if v_change.value is null then
        perform data.delete_attribute_value(
          in_object_id,
          v_change.attribute_id,
          v_change.value_object_id,
          in_actor_id);
      else
        perform data.set_attribute_value(
          in_object_id,
          v_change.attribute_id,
          v_change.value,
          v_change.value_object_id,
          in_actor_id);
      end if;
    end loop;
  end;

  -- Берём новые атрибуты и действия для тех же клиентов
  if v_subscriptions != jsonb '[]' then
    declare
      v_subscription record;
      v_full_card_function text := json.get_string_opt(data.get_attribute_value(in_object_id, 'full_card_function'), null);
      v_new_data jsonb;
      v_object jsonb;
      v_list_changes jsonb;
      v_attributes jsonb;
      v_actions jsonb;
      v_object_template jsonb;
      v_ret_val_element jsonb;
    begin
      for v_subscription in
      (
        select
          json.get_integer(value, 'id') as id,
          json.get_integer(value, 'client_id') as client_id,
          json.get_integer(value, 'actor_id') as actor_id,
          json.get_object(value, 'data') as data
        from jsonb_array_elements(v_subscriptions)
      )
      loop
        if v_full_card_function is not null then
          execute format('select %s($1, $2)', v_full_card_function)
          using in_object_id, v_subscription.actor_id;
        end if;

        -- Объект стал невидимым - отправляем специальный diff и вычищаем подписки
        if not json.get_boolean_opt(data.get_attribute_value(in_object_id, 'is_visible', v_subscription.actor_id), false) then
          v_ret_val :=
            v_ret_val ||
            jsonb_build_object(
              'object_id',
              v_object_code,
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

        v_new_data := data.get_object(in_object_id, v_subscription.actor_id, 'full', in_object_id);

        v_object := null;
        v_list_changes := jsonb '{}';

        -- Сравниваем и при нахождении различий включаем в diff
        if v_new_data != v_subscription.data then
          v_object := v_new_data;
        end if;

        if v_list_changed then
          declare
            v_content_diff jsonb;
            v_add jsonb;
            v_remove jsonb;
            v_remove_list_changes jsonb;
            v_add_list_changes jsonb := jsonb '[]';
          begin
            v_content_diff :=
              data.calc_content_diff(
                json.get_array_opt(json.get_object_opt(json.get_object(v_subscription.data, 'attributes'), 'content', jsonb '{}'), 'value', null),
                json.get_array_opt(json.get_object_opt(json.get_object(v_new_data, 'attributes'), 'content', jsonb '{}'), 'value', null));

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
                  and cso.is_visible is true;

                if v_remove_list_changes is not null then
                  v_list_changes := v_list_changes || jsonb_build_object('remove', v_remove_list_changes);
                end if;

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
                  v_add_list_change jsonb;
                begin
                  select jsonb_object_agg(o.code, jsonb_build_object('is_visible', cso.is_visible, 'index', cso.index))
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
                    if not v_processed_objects ? v_add_element.position then
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
                              is_visible is true);
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

                    insert into data.client_subscription_objects(client_subscription_id, object_id, index, is_visible)
                    values(v_subscription.id, data.get_object_id(v_add_element.object_code), v_index, v_is_visible);

                    if v_is_visible then
                      v_add_list_change :=
                        jsonb_build_object(
                          'object',
                          data.get_object(v_object_id, v_subscription.actor_id, 'mini', in_object_id));
                      if v_position is not null then
                        v_add_list_change := v_add_list_change || jsonb_build_object('position', v_position);
                      end if;
                      v_add_list_changes := v_add_list_changes || v_add_list_change;
                    end if;
                  end loop;
                end;
              end if;

              if v_add_list_changes != jsonb '[]' then
                v_list_changes := v_list_changes || jsonb_build_object('add', v_add_list_changes);
              end if;
            end if;
          end;
        end if;

        if v_object is not null or v_list_changes != jsonb '{}' then
          v_ret_val_element := jsonb_build_object('object_id', v_object_code, 'client_id', v_subscription.client_id);

          if v_object is not null then
            v_ret_val_element := v_ret_val_element || jsonb_build_object('object', v_object);
          end if;

          if v_list_changes!= jsonb '{}' then
            v_ret_val_element := v_ret_val_element || jsonb_build_object('list_changes', v_list_changes);
          end if;

          v_ret_val := v_ret_val || v_ret_val_element;
        end if;
      end loop;
    end;
  end if;

  -- Берём новые миникарточки для тех же списков
  if v_subscription_objects != jsonb '[]' then
    declare
      v_mini_card_function text := json.get_string_opt(data.get_attribute_value(in_object_id, 'mini_card_function'), null);
      v_list record;
      v_new_data jsonb;
      v_attributes jsonb;
      v_actions jsonb;
      v_set_visible integer[];
      v_set_invisible integer[];
      v_object_template jsonb;
      v_object jsonb;
      v_position_object_id integer;
      v_add jsonb;
      v_subscription_object_code text;
    begin
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
        from jsonb_array_elements(v_subscription_objects)
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
            v_object = v_new_data;
            v_subscription_object_code := data.get_object_code(v_list.object_id);

            if not v_list.is_visible then
              v_set_visible := array_append(v_set_visible, v_list.id);

              v_add := jsonb_build_object('object', v_object);

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
                  jsonb_build_object('change', jsonb_build_array(v_object)));
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
    end;
  end if;

  return v_ret_val;
end;
$$
language plpgsql;
