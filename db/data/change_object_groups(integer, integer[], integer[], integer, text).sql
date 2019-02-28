-- drop function data.change_object_groups(integer, integer[], integer[], integer, text);

create or replace function data.change_object_groups(in_object_id integer, in_add integer[], in_remove integer[], in_actor_id integer, in_reason text default null::text)
returns jsonb
volatile
as
$$
-- В параметре in_add приходит массив объектов, в которые нужно добавить объект
-- В параметре in_remove приходит массив объектов, из которых нужно убрать объект

-- Возвращается массив объектов с полями object_id, client_id, object и list_changes, поля object и list_changes могут отсутствовать
declare
  v_parent_object_id integer;
  v_actor_subscriptions jsonb := jsonb '[]';
begin
  assert coalesce(array_length(in_add, 1), 0) + coalesce(array_length(in_remove, 1), 0) > 0;

  -- Сохраняем подписки клиентов актора
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
        where actor_id = in_object_id);

    v_actor_subscriptions := data_internal.save_state(v_ids, null, data.get_attribute_id('independent_from_actor_list_elements'));
  end;

  -- Меняем группы объектов
  for v_parent_object_id in
  (
    select value
    from unnest(in_add) a(value)
  )
  loop
    perform data.add_object_to_object(in_object_id, v_parent_object_id, in_actor_id, in_reason);
  end loop;

  for v_parent_object_id in
  (
    select value
    from unnest(in_remove) a(value)
  )
  loop
    perform data.remove_object_from_object(in_object_id, v_parent_object_id, in_actor_id, in_reason);
  end loop;

  -- Обрабатываем изменения подписок клиентов изменённого актора
  return data_internal.process_saved_state(v_actor_subscriptions);
end;
$$
language plpgsql;
