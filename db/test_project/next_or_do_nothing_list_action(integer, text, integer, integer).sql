-- drop function test_project.next_or_do_nothing_list_action(integer, text, integer, integer);

create or replace function test_project.next_or_do_nothing_list_action(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_object_title text := test_project.next_code(json.get_string(data.get_attribute_value(in_object_id, 'title', v_actor_id)));
  v_list_object_title text := json.get_string_opt(data.get_attribute_value(in_list_object_id, 'title', v_actor_id), null);
  v_object_id integer;
  v_object_code text;
  v_content jsonb := jsonb '[]';
  v_login_id integer;
begin
  assert in_request_id is not null;

  if v_list_object_title = 'Далее' then
    -- Два элемента списка

    insert into data.objects
    default values
    returning id, code into v_object_id, v_object_code;

    v_content := v_content || to_jsonb(v_object_code);

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_object_id, data.get_attribute_id('type'), jsonb '"list_object"'),
    (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
    (v_object_id, data.get_attribute_id('title'), jsonb '"One"'),
    (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "groups":[]}');

    insert into data.objects
    default values
    returning id, code into v_object_id, v_object_code;

    v_content := v_content || to_jsonb(v_object_code);

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_object_id, data.get_attribute_id('type'), jsonb '"list_object"'),
    (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
    (v_object_id, data.get_attribute_id('title'), jsonb '"Two"'),
    (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "groups":[]}');

    -- И основной объект

    insert into data.objects
    default values
    returning id, code into v_object_id, v_object_code;

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_object_id, data.get_attribute_id('type'), jsonb '"test"'),
    (v_object_id, data.get_attribute_id('test_state'), jsonb '"remove_list"'),
    (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
    (v_object_id, data.get_attribute_id('content'), v_content),
    (v_object_id, data.get_attribute_id('actions_function'), jsonb '"test_project.list_diff_action_generator"'),
    (v_object_id, data.get_attribute_id('list_element_function'), jsonb '"test_project.next_or_do_nothing_list_action"'),
    (v_object_id, data.get_attribute_id('title'), to_jsonb(v_object_title)),
    (v_object_id, data.get_attribute_id('subtitle'), jsonb '"Тест удаления списка"'),
    (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "subtitle": "subtitle", "groups": [{"code": "main", "attributes": ["description2"], "actions": ["action"]}]}'),
    (v_object_id, data.get_attribute_id('description2'), to_jsonb(text
'**Проверка:** По нажатию на кнопку "Далее" изменится заголовок, подзаголовок, описание объекта, а также удалится список!'));

    -- Создадим новый логин
    insert into data.logins
    default values
    returning id into v_login_id;

    -- Привяжем тест к логину
    insert into data.login_actors(login_id, actor_id)
    values(v_login_id, v_object_id);

    -- Заменим логин
    perform data.set_login(in_client_id, v_login_id);

    -- И отправим новый список акторов
    perform api_utils.process_get_actors_message(in_client_id, in_request_id);
  else
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
