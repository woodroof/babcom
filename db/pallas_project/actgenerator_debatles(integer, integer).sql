-- drop function pallas_project.actgenerator_debatles(integer, integer);

create or replace function pallas_project.actgenerator_debatles(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

  if pallas_project.is_in_group(in_actor_id, 'all_person') then
    v_actions_list := v_actions_list || 
      ', "create_debatle_step1": {"code": "create_debatle_step1", "name": "Инициировать дебатл", "disabled": false, '||
      '"params": {}, "user_params": [{"code": "title", "description": "Введите тему дебатла", "type": "string" }]}';
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
