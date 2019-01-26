-- drop function test_project.list_diff_action(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.list_diff_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_object_code text := json.get_string(in_params);
  v_object_id integer := data.get_object_id(v_object_code);
  v_test_state text := json.get_string(data.get_attribute_value(v_object_id, 'test_state'));
  v_changes jsonb := jsonb '[]';
begin
  assert test_project.is_user_params_empty(in_user_params);
  assert in_default_params is null;

  v_changes :=
    v_changes ||
    data.attribute_change2jsonb(
      'title',
      null,
      to_jsonb(
        test_project.next_code(
          json.get_string(
            data.get_attribute_value(
              v_object_id,
              'title',
              v_actor_id)))));
  if v_test_state = 'remove_list' then
    v_changes := v_changes || data.attribute_change2jsonb('subtitle', null, jsonb '"Тест добавления списка"');
    v_changes := v_changes || data.attribute_change2jsonb('content', null, jsonb '[]');
    v_changes := v_changes || data.attribute_change2jsonb('test_state', null, jsonb '"add_list"');
    v_changes := v_changes || data.attribute_change2jsonb('description2', null, to_jsonb(text
'**Проверка 1:** Вместо удалённого списка появилась заглушка.
**Проверка 2:** По действию изменится заголовок, подзаголовок, описание, а также добавится два элемента списка.'));
  elsif v_test_state = 'add_list' then
    -- todo
  end if;

  assert data.change_current_object(in_client_id, in_request_id, v_object_id, v_changes);
end;
$$
language plpgsql;
