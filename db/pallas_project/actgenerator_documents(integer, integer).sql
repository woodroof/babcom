-- drop function pallas_project.actgenerator_documents(integer, integer);

create or replace function pallas_project.actgenerator_documents(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
    ', "document_create": {"code": "document_create", "name": "Создать документ", "disabled": false, 
     "params": {}, "user_params": [{"code": "title", "description": "Введите заголовок документа", "type": "string", "restrictions": {"min_length": 1}}]}';

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
