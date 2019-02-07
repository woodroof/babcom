-- drop function test_project.simple_list_generator(integer, integer);

create or replace function test_project.simple_list_generator(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_content jsonb := data.get_attribute_value(in_object_id, 'content', in_actor_id);
  v_object_id integer;
  v_object_code text;
begin
  if v_content is not null then
    return;
  end if;

  v_content := jsonb '[]';

  -- Первый объект

  insert into data.objects
  default values
  returning id, code into v_object_id, v_object_code;

  v_content := v_content || to_jsonb(v_object_code);

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_object_id, data.get_attribute_id('type'), jsonb '"list_object"'),
  (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
  (v_object_id, data.get_attribute_id('title'), jsonb '"Uno"'),
  (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "groups": [{"code": "main", "attributes": ["description2"]}]}'),
  (v_object_id, data.get_attribute_id('description2'), jsonb '"Первый элемент списка"');

  -- Второй объект

  insert into data.objects
  default values
  returning id, code into v_object_id, v_object_code;

  v_content := v_content || to_jsonb(v_object_code);

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_object_id, data.get_attribute_id('type'), jsonb '"list_object"'),
  (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
  (v_object_id, data.get_attribute_id('title'), jsonb '"Duo"'),
  (v_object_id, data.get_attribute_id('subtitle'), jsonb '"Второй элемент списка"'),
  (v_object_id, data.get_attribute_id('attribute_with_description'), jsonb '"значение"'),
  (v_object_id, data.get_attribute_id('attribute'), jsonb '"значение"'),
  (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "subtitle": "subtitle", "groups": [{"code": "main", "attributes": ["description2"]}, {"code": "additional", "name": "Группа элемента списка", "attributes": ["short_card_attribute", "attribute_with_description", "attribute"], "actions": ["action"]}]}'),
  (v_object_id, data.get_attribute_id('description2'), to_jsonb(text
'**Проверка 1:** В этом объекте списка две группы.
**Проверка 2:** У второй группы есть имя "Группа элемента списка".
**Проверка 3:** Во второй группе есть три атрибута.
**Проверка 4:** У первого есть имя, но нет значения.
**Проверка 5:** У второго есть только описание значения.
**Проверка 6:** У третьего есть имя и значение.
**Проверка 7:** Под атрибутами есть действие.
**Проверка 8:** При выборе действия выполняется именно оно.'));

  -- Третий объект

  insert into data.objects
  default values
  returning id, code into v_object_id, v_object_code;

  v_content := v_content || to_jsonb(v_object_code);

  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_object_id, data.get_attribute_id('type'), jsonb '"list_object"'),
  (v_object_id, data.get_attribute_id('is_visible'), jsonb 'true'),
  (v_object_id, data.get_attribute_id('title'), jsonb '"Далее"'),
  (v_object_id, data.get_attribute_id('template'), jsonb '{"title": "title", "groups": [{"code": "main", "attributes": ["description2"]}]}'),
  (v_object_id, data.get_attribute_id('description2'), jsonb '"Ничтоже сумняшеся выбираем этот элемент для перехода к следующему тесту"');

  -- Заполняем параметры оригинального объекта

  perform data.set_attribute_value(in_object_id, data.get_attribute_id('content'), v_content, null, in_actor_id);
  perform data.set_attribute_value(in_object_id, data.get_attribute_id('list_element_function'), jsonb '"test_project.next_or_do_nothing_list_action"', null, in_actor_id);
end;
$$
language plpgsql;
