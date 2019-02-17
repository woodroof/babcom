-- drop function pallas_project.actgenerator_document_content(integer, integer, integer);

create or replace function pallas_project.actgenerator_document_content(in_object_id integer, in_list_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_master_group_id integer := data.get_object_id('master');
  v_document_code text := data.get_object_code(in_object_id);
  v_list_code text := data.get_object_code(in_list_object_id);
  v_document_author integer := json.get_integer(data.get_attribute_value(in_object_id, 'system_document_author'));
  v_document_category text := json.get_string(data.get_attribute_value(in_object_id, 'system_document_category'));
  v_document_status text := json.get_string_opt(data.get_attribute_value(in_object_id, 'document_status'),'');
begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');
  if v_document_status <> 'deleted' then
    if v_document_category = 'official' and v_document_status = 'draft' and (v_is_master or in_actor_id = v_document_author) then
      v_actions_list := v_actions_list || 
          format(', "document_delete_signer": {"code": "document_delete_signer", "name": "Удалить", "disabled": false, '||
                  '"params": {"document_code": "%s", "list_code": "%s"}}',
                  v_document_code,
                  v_list_code);
    end if;
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
