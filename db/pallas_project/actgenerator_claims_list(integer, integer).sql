-- drop function pallas_project.actgenerator_claims_list(integer, integer);

create or replace function pallas_project.actgenerator_claims_list(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  if v_object_code <> 'claims_all' 
  and (pp_utils.is_in_group(in_actor_id, 'all_person') or pp_utils.is_in_group(in_actor_id, 'master')) then
    v_actions_list := v_actions_list || 
      format(', "claim_create": {"code": "claim_create", "name": "Создать иск", "disabled": false, '||
        '"params": {"claim_list": "%s"}, "user_params": [{"code": "title", "description": "Введите заголовок иска", "type": "string", "restrictions": {"min_length": 1}},
                                                         {"code": "claim_text", "description": "Введите текст иска", "type": "string", "restrictions": {"min_length": 1, "multiline": true}}]}',
        v_object_code);
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
