-- drop function pallas_project.act_create_debatle_step1(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_create_debatle_step1(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text := json.get_string(in_user_params, 'title');
  v_debatle_code text;
  v_debatle_id  integer;
  v_debatle_class_id integer := data.get_class_id('debatle');
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_debatle_theme_attribute_id integer := data.get_attribute_id('system_debatle_theme');
  v_debatle_status_attribute_id integer := data.get_attribute_id('debatle_status');
  v_system_debatle_person1_attribute_id integer := data.get_attribute_id('system_debatle_person1');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');

  v_debatles_all_id integer := data.get_object_id('debatles_all');
  v_debatles_my_id integer := data.get_object_id('debatles_my');
  v_debatles_draft_id integer := data.get_object_id('debatles_draft');
  v_master_group_id integer := data.get_object_id('master');

  v_content text[];
  v_new_content text[];

  v_temp_object_code text;
  v_temp_object_id integer;
begin
  assert in_request_id is not null;
  -- создаём новый дебатл
  insert into data.objects(class_id) values (v_debatle_class_id) returning id, code into v_debatle_id, v_debatle_code;

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatle_id, v_debatle_theme_attribute_id, to_jsonb(v_title), null),
  (v_debatle_id, v_debatle_status_attribute_id, jsonb '"draft"', null),
  (v_debatle_id, v_is_visible_attribute_id, jsonb 'true', v_actor_id),
  (v_debatle_id, v_is_visible_attribute_id, jsonb 'true', v_master_group_id),
  (v_debatle_id, v_system_debatle_person1_attribute_id, to_jsonb(v_actor_id), null);

  -- Добавляем его в список всех и в список моих для того, кто создаёт
  -- Блокируем списки
  perform * from data.objects where id = v_debatles_all_id for update;
  perform * from data.objects where id = v_debatles_my_id for update;
  perform * from data.objects where id = v_debatles_draft_id for update;

  -- Достаём, меняем, кладём назад
  v_content := array[]::text[];
  v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_all_id, 'content', v_master_group_id), v_content);
  v_new_content := array_append(v_content, v_debatle_code);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(v_debatles_all_id, 
                                          jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_master_group_id, to_jsonb(v_new_content))),
                                          v_actor_id);
  end if;
  v_content := array[]::text[];
  v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_my_id,'content', v_actor_id), v_content);
  v_new_content := array_append(v_content, v_debatle_code);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(v_debatles_my_id, 
                                         jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_actor_id, to_jsonb(v_new_content))),
                                         v_actor_id);
  end if;
  v_content := array[]::text[];
  v_content := json.get_string_array_opt(data.get_attribute_value(v_debatles_draft_id,'content', v_actor_id), v_content);
  v_new_content := array_append(v_content, v_debatle_code);
  if v_new_content <> v_content then
    perform data.change_object_and_notify(v_debatles_draft_id, 
                                          jsonb_build_array(data.attribute_change2jsonb(v_content_attribute_id, v_actor_id, to_jsonb(v_new_content))),
                                          v_actor_id);
  end if;

  perform api_utils.create_notification(
    in_client_id,
    in_request_id,
    'action',
    format('{"action": "open_object", "action_data": {"object_id": "%s"}}', v_debatle_code)::jsonb);
end;
$$
language plpgsql;
