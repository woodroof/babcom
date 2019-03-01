-- drop function pallas_project.actgenerator_customs(integer, integer);

create or replace function pallas_project.actgenerator_customs(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  if pp_utils.is_in_group(in_actor_id, 'master') then
    v_actions_list := v_actions_list || 
      ', "customs_ship_arrival": {"code": "customs_ship_arrival", "name": "Прилёт корабля", "disabled": false, '||
      '"params": {}, "user_params": [{"code": "ship", "description": "Название корабля", "type": "string", "restrictions": {"min_length": 1}}]}';
    v_actions_list := v_actions_list || 
      ', "customs_future_packages": {"code": "act_open_object", "name": "Будущие грузы", "disabled": false, "params": {"object_code": "customs_future_packages"}}';

  end if;
  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
