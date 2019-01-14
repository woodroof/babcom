-- drop function test_project.login_action(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.login_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text := test_project.next_code(json.get_string(in_params));
  v_login_id integer;
  v_object_id integer;
begin
  perform data.get_active_actor_id(in_client_id);

  assert in_request_id is not null;
  assert in_user_params is null;
  assert in_default_params is null;

  -- Создадим новый логин
  insert into data.logins
  default values
  returning id into v_login_id;

  -- Создадим действия для тестов на изменение объекта
  insert into data.actions(code, function)
  values('diff', 'test_project.diff_action');

  -- Создадим тест
  insert into data.objects
  default values
  returning id into v_object_id;

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_object_id, data.get_attribute_id('type'), jsonb '"test"'),
  (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
  -- todo
  --(v_object_id, data.get_attribute_id('actions_function'), jsonb '"test_project.diff_generator"'),
  (v_object_id, data.get_attribute_id('title'), to_jsonb(v_title)),
  (
    v_object_id,
    data.get_attribute_id('description'),
    to_jsonb(text
-- todo что-нибудь про заголовок в списке акторов, атрибут test_state
'Ура!')
  );

  -- Привяжем тест к логину
  insert into data.login_actors(login_id, actor_id)
  values(v_login_id, v_object_id);

  -- Заменим логин
  perform data.set_login(in_client_id, v_login_id);

  -- И отправим новый список акторов
  perform api_utils.process_get_actors_message(in_client_id, in_request_id);
end;
$$
language 'plpgsql';
