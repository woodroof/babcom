-- drop function pallas_project.act_debatle_create(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_debatle_create(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_title text := json.get_string(in_user_params, 'title');
  v_debatle_code text;
  v_debatle_id  integer;
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_debatles_all_id integer := data.get_object_id('debatles_all');
  v_debatles_my_id integer := data.get_object_id('debatles_my');

  v_master_group_id integer := data.get_object_id('master');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_system_debatle_confirm_presence_id_attribute_id integer := data.get_attribute_id('system_debatle_confirm_presence_id');
  v_debatle_confirm_presence_link_attribute_id integer := data.get_attribute_id('debatle_confirm_presence_link');
v_debatle_confirm_presence_id integer;
begin
  assert in_request_id is not null;
  -- создаём новый дебатл

  v_debatle_id := data.create_object(
    null,
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', v_title),
      jsonb_build_object('code', 'debatle_status', 'value', 'draft'),
      jsonb_build_object('code', 'debatle_person1', 'value', to_jsonb(data.get_object_code(v_actor_id)))
    ),
    'debatle');

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatle_id, v_is_visible_attribute_id, jsonb 'true', v_debatle_id);

  perform data.add_object_to_object(v_actor_id, v_debatle_id);

  v_debatle_code := data.get_object_code(v_debatle_id);

  perform data.create_object(
    v_debatle_code || '_target_audience',
    jsonb_build_array(
      jsonb_build_object('code', 'is_visible', 'value', true, 'value_object_id', v_debatle_id)
    ),
    'debatle_target_audience');

  v_debatle_confirm_presence_id := data.create_object(
    null,
    jsonb_build_array(
      jsonb_build_object('code', 'system_debatle_id', 'value', v_debatle_id)
    ),
    'debatle_confirm_presence');

  insert into data.attribute_values(object_id, attribute_id, value, value_object_id) values
  (v_debatle_id, v_system_debatle_confirm_presence_id_attribute_id, to_jsonb(v_debatle_confirm_presence_id), null),
  (v_debatle_id, v_debatle_confirm_presence_link_attribute_id, to_jsonb(json.get_string_opt(data.get_param('objects_url'), '') || data.get_object_code(v_debatle_confirm_presence_id)), v_master_group_id);

  -- Добавляем дебатл в список всех и в список моих для того, кто создаёт
  perform pp_utils.list_prepend_and_notify(v_debatles_all_id, v_debatle_code, v_master_group_id, v_actor_id);
  perform pp_utils.list_prepend_and_notify(v_debatles_my_id, v_debatle_code, v_actor_id, v_actor_id);

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_debatle_code);
end;
$$
language plpgsql;
