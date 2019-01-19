-- drop function test_project.diff_action(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.diff_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_title text := test_project.next_code(json.get_string(in_params, 'title'));
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_object_code text := data.get_object_code(v_object_id);
  v_state text := json.get_string(data.get_attribute_value(v_object_id, 'test_state'));
  v_changes jsonb := jsonb '[]';
  v_diffs jsonb;
  v_diff record;
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;
  assert test_project.is_user_params_empty(in_user_params);
  assert in_default_params is null;

  if v_state = 'state1' then
    v_changes := v_changes || data.attribute_change2jsonb('test_state', null, jsonb '"state2"');
    v_changes := v_changes || data.attribute_change2jsonb('title', null, to_jsonb(v_title));
    v_changes := v_changes || data.attribute_change2jsonb('description', null, to_jsonb(
'**Проверка 1:** Заголовок изменился на "' || v_title || '".
**Проверка 2:** Название кнопки поменялось на "Вперёд!".
**Проверка 3:** Действие в очередной раз полностью меняет отображаемые данные.'));
  elsif v_state = 'state2' then
    v_changes := v_changes || data.attribute_change2jsonb('test_state', null, jsonb '"state3"');
    v_changes := v_changes || data.attribute_change2jsonb('title', null, to_jsonb(v_title));
    v_changes := v_changes || data.attribute_change2jsonb('subtitle', null, jsonb '"Тест на удаление и добавление атрибутов"');
    v_changes := v_changes || data.attribute_change2jsonb('description', null, null);
    v_changes := v_changes || data.attribute_change2jsonb('template', null, jsonb '{"groups": [{"code": "not_so_common", "attributes": ["description2"]}]}');
    v_changes := v_changes || data.attribute_change2jsonb('description2', null, to_jsonb(text
'В этот раз мы не изменяли значение атрибута, а удалили старый и добавили новый. Также какое-то действие возвращается, но оно отсутствует в шаблоне.

**Проверка 1:** Под заголовком гордо красуется подзаголовок.
**Проверка 2:** Старого текста нигде нет.
**Проверка 3:** Действий тоже нет.

[Продолжить](babcom:test' || (test_project.get_suffix(v_title) + 1) || ')'));
  end if;

  assert v_changes != jsonb '[]';

  v_diffs := data.change_object(v_object_id, v_changes, v_actor_id);

  for v_diff in
  (
    select
      json.get_integer(value, 'client_id') as client_id,
      json.get_object(value, 'object') as object
    from jsonb_array_elements(v_diffs)
  )
  loop
    if v_diff.client_id = in_client_id then
      assert v_message_sent is false;

      v_message_sent := true;

      perform api_utils.create_notification(v_diff.client_id, in_request_id, 'diff', jsonb_build_object('object_id', v_object_code, 'object', v_diff.object));
    else
      perform api_utils.create_notification(v_diff.client_id, null, 'diff', jsonb_build_object('object_id', v_object_code, 'object', v_diff.object));
    end if;
  end loop;

  if v_message_sent is false then
    perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language 'plpgsql';
