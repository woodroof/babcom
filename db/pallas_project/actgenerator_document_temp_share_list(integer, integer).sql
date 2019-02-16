-- drop function pallas_project.actgenerator_document_temp_share_list(integer, integer);

create or replace function pallas_project.actgenerator_document_temp_share_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_share_list_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  v_actions_list := v_actions_list || 
                ', "go_back": {"code": "go_back", "name": "Передумал делиться", "disabled": false, '||
                '"params": {}}';

  v_actions_list := v_actions_list || 
          format(', "document_share": {"code": "document_share", "name": "Поделиться", "disabled": false, "warning": "Ссылка на документ будет отправлена выбранным лицам, и забрать её назад вы не сможете. Продолжаем?",'||
                  '"params": {"share_list_code": "%s"}}',
                  v_share_list_code);
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
