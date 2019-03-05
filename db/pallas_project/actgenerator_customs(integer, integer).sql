-- drop function pallas_project.actgenerator_customs(integer, integer);

create or replace function pallas_project.actgenerator_customs(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
begin
  assert in_actor_id is not null;

    v_actions_list := v_actions_list || 
      ', "customs_find_by_number": {"code": "customs_find_by_number", "name": "Поиск по коду груза", "disabled": false, "params": {},
      "user_params": [{"code": "package_number", "description": "Код груза", "type": "string", "restrictions": {"min_length": 3}}]}';

    v_actions_list := v_actions_list || 
      ', "customs_find_by_status_or_from": {"code": "customs_find_by_status_or_from", "name": "Поиск по месту отправки или статусу получателя", "disabled": false, "params": {},
      "user_params": [{"code": "package_from", "description": "Введите планету, спутник или астероид, с которого отправлен груз", "type": "string"},
                      {"code": "package_to_status", "description": "Введите числом статус административного обслуживания получателя груза: -1 - все статусы, 0 - нет статуса, 1 - бронзовый, 2 - серебряный, 3 - золотой", "type": "integer"}]}';


  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
