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
    v_actions_list := v_actions_list || 
      ', "get_my_debatles": {"code": "act_open_object", "name": "Мои дебатлы", "disabled": false, '||
      '"params": {"object_code": "debatles_my"}}';
    v_actions_list := v_actions_list || 
      ', "get_closed_debatles": {"code": "act_open_object", "name": "Завершенные дебатлы", "disabled": false, '||
      '"params": {"object_code": "debatles_closed"}}';
  end if;
  if pallas_project.is_in_group(in_actor_id, 'master') then
    v_actions_list := v_actions_list || 
      ', "get_new_debatles": {"code": "act_open_object", "name": "Неподтверждённые дебатлы", "disabled": false, '||
      '"params": {"object_code": "debatles_new"}}';
    v_actions_list := v_actions_list || 
      ', "get_current_debatles": {"code": "act_open_object", "name": "Теукщие дебатлы", "disabled": false, '||
      '"params": {"object_code": "debatles_current"}}';
    v_actions_list := v_actions_list || 
      ', "get_future_debatles": {"code": "act_open_object", "name": "Будущие дебатлы", "disabled": false, '||
      '"params": {"object_code": "debatles_future"}}';
    v_actions_list := v_actions_list || 
      ', "get_all_debatles": {"code": "act_open_object", "name": "Все дебатлы", "disabled": false, '||
      '"params": {"object_code": "debatles_all"}}';
  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language 'plpgsql';
