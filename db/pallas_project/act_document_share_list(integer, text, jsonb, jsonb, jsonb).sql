-- drop function pallas_project.act_document_share_list(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_document_share_list(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_document_code text := json.get_string(in_params, 'document_code');
  v_document_id integer := data.get_object_id(v_document_code);
  v_actor_id  integer :=data.get_active_actor_id(in_client_id);

  v_content_attribute_id integer := data.get_attribute_id('content');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_system_document_temp_list_document_id_attribute_id integer := data.get_attribute_id('system_document_temp_list_document_id');

  v_document_title text := json.get_string_opt(data.get_attribute_value(v_document_id, v_title_attribute_id, v_actor_id), '');
  v_is_master boolean := pp_utils.is_in_group(in_client_id, 'master');
  v_persons text := '';
  v_name record;

  v_content text[];

  v_temp_object_code text;
  v_temp_object_id integer;

  v_all_person_id integer:= data.get_object_id('all_person');
begin
  assert in_request_id is not null;

  -- Собираем список всех персонажей кроме себя
  select array_agg(o.code order by av.value) into v_content
  from data.object_objects oo
    left join data.objects o on o.id = oo.object_id
    left join data.attribute_values av on av.object_id = o.id and av.attribute_id = v_title_attribute_id and av.value_object_id is null
  where oo.parent_object_id = v_all_person_id
    and oo.object_id not in (oo.parent_object_id, v_actor_id);

  if v_content is null then
     v_content := array[]::integer[];
  end if;

-- создаём темповый список персон
  v_temp_object_id := data.create_object(
  null,
    jsonb_build_array(
      jsonb_build_object('code', 'title', 'value', format('Поделиться документом %s', v_document_title)),
      jsonb_build_object('code', 'is_visible', 'value', true, 'value_object_id', v_actor_id),
      jsonb_build_object('code', 'system_document_temp_list_document_id', 'value', v_document_id),
      jsonb_build_object('code', 'system_document_temp_share_list', 'value', array[]::text[]),
      jsonb_build_object('code', 'document_temp_share_list', 'value', ''),
      jsonb_build_object('code', 'content', 'value', v_content)
    ),
  'document_temp_share_list');

  v_temp_object_code := data.get_object_code(v_temp_object_id);

  perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, v_temp_object_code);
end;
$$
language plpgsql;
