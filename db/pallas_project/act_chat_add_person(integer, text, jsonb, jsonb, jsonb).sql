-- drop function pallas_project.act_chat_add_person(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_chat_add_person(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_chat_code text := json.get_string(in_params, 'chat_code');
  v_chat_id integer := data.get_object_id(v_chat_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_chat_temp_person_list_persons_attribute_id integer := data.get_attribute_id('chat_temp_person_list_persons');
  v_system_chat_temp_person_list_chat_id_attribute_id integer := data.get_attribute_id('system_chat_temp_person_list_chat_id');

  v_chat_title text := json.get_string_opt(data.get_attribute_value(v_chat_id, v_title_attribute_id, v_actor_id), '');
  v_is_master_chat boolean := json.get_boolean_opt(data.get_attribute_value(v_chat_id, 'system_chat_is_master'), false);
  v_persons text := '';
  v_name jsonb;

  v_chat_temp_person_list_class_id integer := data.get_class_id('chat_temp_person_list');
  v_content text[];

  v_temp_object_code text;
  v_temp_object_id integer;

  v_all_person_id integer:= data.get_object_id('all_person');
  v_master_id integer := data.get_object_id('master');
begin
  assert in_request_id is not null;

  -- создаём темповый список персон
  insert into data.objects(class_id) values (v_chat_temp_person_list_class_id) returning id, code into v_temp_object_id, v_temp_object_code;

  -- Собираем список всех персонажей, кроме тех, кто уже в чате
  select array_agg(o.code order by av.value) into v_content
  from data.object_objects oo
    left join data.objects o on o.id = oo.object_id
    left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
  where (oo.parent_object_id = v_all_person_id or oo.parent_object_id = v_master_id and v_is_master_chat)
    and oo.object_id not in (oo.parent_object_id)
    and oo.object_id not in (select chat.object_id from data.object_objects chat where chat.parent_object_id = v_chat_id);

  if v_content is null then
    v_content := array[]::integer[];
  end if;

  -- Собираем список тех, кто уже в чате, просто чтобы показать
  for v_name in (select * from unnest(pallas_project.get_chat_persons(v_chat_id, not v_is_master_chat))) loop 
    v_persons := v_persons || '
'|| json.get_string_opt(v_name, '');
  end loop;
  v_persons := v_persons || '
'|| '------------------
Кого добавляем?';
  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_temp_object_id, v_title_attribute_id, to_jsonb(format('Изменение участников чата %s', v_chat_title)), v_actor_id),
  (v_temp_object_id, v_is_visible_attribute_id, jsonb 'true', v_actor_id),
  (v_temp_object_id, v_chat_temp_person_list_persons_attribute_id, to_jsonb(v_persons), null),
  (v_temp_object_id, v_content_attribute_id, to_jsonb(v_content), null),
  (v_temp_object_id, v_system_chat_temp_person_list_chat_id_attribute_id, to_jsonb(v_chat_id), null);

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    format('{"action": "open_object", "action_data": {"object_id": "%s"}}', v_temp_object_code)::jsonb);
end;
$$
language plpgsql;
