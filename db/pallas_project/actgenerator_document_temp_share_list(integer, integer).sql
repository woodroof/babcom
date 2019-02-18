-- drop function pallas_project.actgenerator_document_temp_share_list(integer, integer);

create or replace function pallas_project.actgenerator_document_temp_share_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_share_list_code text := data.get_object_code(in_object_id);
  v_system_document_temp_share_list integer[] := json.get_integer_array_Opt(data.get_attribute_value_for_share(in_object_id, 'system_document_temp_share_list'),array[]::integer[]);
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "go_back": {"code": "go_back", "name": "Передумал делиться", "disabled": false, '||
                '"params": {}}';

  v_actions_list := v_actions_list || 
          format(', "document_share": {"code": "document_share", "name": "Поделиться", "disabled": %s, "warning": "Ссылка на документ будет отправлена выбранным лицам, и забрать её назад вы не сможете. Продолжаем?",'||
                  '"params": {"share_list_code": "%s"}}',
                  (case when coalesce(array_length(v_system_document_temp_share_list, 1), 0) = 0 then 'true' else 'false' end),
                  v_share_list_code);
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
