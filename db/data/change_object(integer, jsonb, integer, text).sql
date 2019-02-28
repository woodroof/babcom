-- drop function data.change_object(integer, jsonb, integer, text);

create or replace function data.change_object(in_object_id integer, in_changes jsonb, in_actor_id integer default null::integer, in_reason text default null::text)
returns jsonb
volatile
as
$$
-- У параметра in_changes есть два возможных формата:
-- 1. Только для установки значения: объект, где ключ - код атрибута, а значение - значение атрибута
-- 2. Массив объектов с полями id или code, value_object_id, или value_object_code, value
-- Если присутствует value_object_id или value_object_code, то изменится именно значение, задаваемое для указанного объекта
-- Если value отсутствует (именно отсутствует, а не равно jsonb 'null'!), то указанное значение удаляется, в противном случае - устанавливается

-- Возвращается массив объектов с полями object_id, client_id, object и list_changes, поля object и list_changes могут отсутствовать
declare
  v_changes jsonb := data.filter_changes(in_object_id, data.preprocess_changes_with_codes(in_changes));

  v_subscriptions jsonb := jsonb '[]';
  v_subscription_objects jsonb := jsonb '[]';
  v_actor_subscriptions jsonb := jsonb '[]';

  v_ret_val jsonb := jsonb '[]';
begin
  assert in_actor_id is null or data.is_instance(in_actor_id);

  if v_changes = jsonb '[]' then
    return jsonb '[]';
  end if;

  -- Сохраним атрибуты и действия для всех клиентов, подписанных на получение изменений данного объекта
  declare
    v_ids integer[];
  begin
    select array_agg(id)
    into v_ids
    from data.client_subscriptions
    where object_id = in_object_id;

    v_subscriptions := data_internal.save_state(v_ids, null, data.get_attribute_id('independent_from_object_list_elements'));
  end;

  -- Сохраним состояние миникарточек в списках, в которые входит данный объект
  v_subscription_objects := data_internal.save_minicard_state(in_object_id);

  -- Если изменяется актор, то сохраняем подписки его клиентов
  declare
    v_ids integer[];
  begin
    select array_agg(id)
    into v_ids
    from data.client_subscriptions
    where
      client_id in (
        select id
        from data.clients
        where actor_id = in_object_id) and
      object_id != in_object_id;

    v_actor_subscriptions := data_internal.save_state(v_ids, array[in_object_id], data.get_attribute_id('independent_from_actor_list_elements'));
  end;

  -- Меняем состояние объекта
  declare
    v_change record;
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
      if v_change.value is null then
        perform data.delete_attribute_value(
          in_object_id,
          v_change.attribute_id,
          v_change.value_object_id,
          in_actor_id,
          in_reason);
      else
        perform data.set_attribute_value(
          in_object_id,
          v_change.attribute_id,
          v_change.value,
          v_change.value_object_id,
          in_actor_id,
          in_reason);
      end if;
    end loop;
  end;

  -- Берём новые атрибуты и действия для тех же клиентов
  v_ret_val := v_ret_val || data_internal.process_saved_state(v_subscriptions);

  -- Берём новые миникарточки для тех же списков
  v_ret_val := v_ret_val || data_internal.process_saved_minicard_state(in_object_id, v_subscription_objects);

  -- И обрабатываем изменения подписок клиентов изменённого актора
  v_ret_val := v_ret_val || data_internal.process_saved_state(v_actor_subscriptions);

  return v_ret_val;
end;
$$
language plpgsql;
