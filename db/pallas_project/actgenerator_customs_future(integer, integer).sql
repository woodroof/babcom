-- drop function pallas_project.actgenerator_customs_future(integer, integer);

create or replace function pallas_project.actgenerator_customs_future(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean := pp_utils.is_in_group(in_actor_id, 'master');
begin
  assert in_actor_id is not null;

  if v_is_master then
    v_actions_list := v_actions_list || ', "customs_create_future_package": {"code": "customs_create_future_package", "name": "Добавить будущую посылку", "disabled": false, '||
                '"params": {}}';
    v_actions_list := v_actions_list || ', "customs_ship_arrival": {"code": "customs_ship_arrival", "name": "Прибытие корабля с кучей случайных посылок", "disabled": false, "warning": "Постарайтесь не использовать эту кнопку, если осталось ещё много непроверенных посылок (то есть не чаще чем раз в 2 часа). Чревато тормозами.",'||
                '"params": {}}';
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
