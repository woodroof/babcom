-- drop function pallas_project.actgenerator_blogs_news(integer, integer);

create or replace function pallas_project.actgenerator_blogs_news(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

    v_actions_list := v_actions_list || 
      ', "blogs_my": {"code": "act_open_object", "name": "Мои блоги", "disabled": false, "params": {"object_code": "blogs_my"}}';
    v_actions_list := v_actions_list || 
      ', "blogs_all": {"code": "act_open_object", "name": "Все блоги", "disabled": false, "params": {"object_code": "blogs_all"}}';

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
