-- drop function pallas_project.actgenerator_blogs_my(integer, integer);

create or replace function pallas_project.actgenerator_blogs_my(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  if pp_utils.is_in_group(in_actor_id, 'all_person') or pp_utils.is_in_group(in_actor_id, 'master') then
    v_actions_list := v_actions_list || 
      ', "blog_create": {"code": "blog_create", "name": "Создать блог", "disabled": false, '||
      '"params": {}, "user_params": [{"code": "title", "description": "Введите название блога (его можно будет поменять, если захочется)", "type": "string", "restrictions": {"min_length": 1}}]}';
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
