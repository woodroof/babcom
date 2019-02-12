-- drop function pallas_project.actgenerator_document(integer, integer);

create or replace function pallas_project.actgenerator_document(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_master_group_id integer := data.get_object_id('master');
  v_document_code text := data.get_object_code(in_object_id);
  v_document_author integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_document_author'));
  v_document_category text := json.get_string(data.get_attribute_value(in_object_id, 'system_document_category'));
  v_document_status text := json.get_string_opt(data.get_attribute_value(in_object_id, 'document_status',v_master_group_id),'');
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');

  if v_is_master or (in_actor_id = v_document_author and v_document_category = 'private') then
    v_actions_list := v_actions_list || 
        format(', "document_edit": {"code": "document_edit", "name": "Редактировать", "disabled": false, "params": {"document_code": "%s"}, 
"user_params": [{"code": "title", "description": "Заголовок", "type": "string", "restrictions": {"min_length": 1}, "default_value": "%s"},
{"code": "document_text", "description": "Текст документа", "type": "string", "restrictions": {"min_length": 1, "multiline": true}, "default_value": %s}]}',
                v_document_code,
                json.get_string_opt(data.get_attribute_value(in_object_id, 'title', in_actor_id), null),
                coalesce(data.get_attribute_value(in_object_id, 'document_text')::text, '""'));

    if v_document_status <> 'deleted' then
      v_actions_list := v_actions_list || 
          format(', "document_delete": {"code": "document_delete", "name": "Удалить", "disabled": false, "warning": "Документ исчезнет безвозвратно. Точно удаляем?", '||
                  '"params": {"document_code": "%s"}}',
                  v_document_code);
    end if;
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
