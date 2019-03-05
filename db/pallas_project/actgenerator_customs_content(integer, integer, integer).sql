-- drop function pallas_project.actgenerator_customs_content(integer, integer, integer);

create or replace function pallas_project.actgenerator_customs_content(in_object_id integer, in_list_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_object_code text := data.get_object_code(in_list_object_id);
  v_list_code text := data.get_object_code(in_object_id);
  v_package_status text := json.get_string(data.get_attribute_value_for_share(in_list_object_id, 'package_status'));
  v_system_customs_checking boolean := json.get_boolean_opt(data.get_attribute_value_for_share(in_object_id, 'system_customs_checking'), false);
begin
  assert in_actor_id is not null;

  if v_package_status in ('new', 'checking') then
    v_actions_list := v_actions_list || 
      format(', "customs_package_set_checked": {"code": "customs_package_set_status", "name": "Проверено", "disabled": false, 
      "params": {"package_code": "%s", "from_list": "%s", "status": "checked"}}',
      v_object_code,
      v_list_code);
    v_actions_list := v_actions_list || 
      format(', "customs_package_set_frozen": {"code": "customs_package_set_status", "name": "Задержать", "disabled": false, "warning": "Задержать груз можно только при возникновении подозрений о провозе запрещённых товаров. После задержания нельзя проводить проверки.",
      "params": {"package_code": "%s", "from_list": "%s", "status": "frozen"}}',
      v_object_code,
      v_list_code);
    v_actions_list := v_actions_list || 
      format(', "customs_package_check_spectrometer": {"code": "customs_package_check", "name": "Cпектрометр", "disabled": %s, 
      "params": {"package_code": "%s", "from_list": "%s", "check_type": "life"}}',
      case when v_system_customs_checking then 'true' else 'false' end,
      v_object_code,
      v_list_code);
    v_actions_list := v_actions_list || 
      format(', "customs_package_check_radiation": {"code": "customs_package_check", "name": "Радиационная проверка", "disabled": %s, 
      "params": {"package_code": "%s", "from_list": "%s", "check_type": "radiation"}}',
      case when v_system_customs_checking then 'true' else 'false' end,
      v_object_code,
      v_list_code);
    v_actions_list := v_actions_list || 
      format(', "customs_package_chack_x_ray": {"code": "customs_package_check", "name": "Рентген", "disabled": %s, 
      "params": {"package_code": "%s", "from_list": "%s", "check_type": "metal"}}',
      case when v_system_customs_checking then 'true' else 'false' end,
      v_object_code,
      v_list_code);
  end if;
  if v_package_status in ('new', 'checking', 'frozen') then
    v_actions_list := v_actions_list || 
      format(', "customs_package_set_arrested": {"code": "customs_package_set_status", "name": "Арестовать", "disabled": false, "warning": "Арестовать груз можно только при наличии ордера из полиции. Вы уверены, что ордер есть?",
      "params": {"package_code": "%s", "from_list": "%s", "status": "arrested"}}',
      v_object_code,
      v_list_code);
  end if;
  if v_package_status in ('frozen', 'arrested') then
    v_actions_list := v_actions_list || 
      format(', "customs_package_set_new": {"code": "customs_package_set_status", "name": "Вернуть на проверку", "disabled": false, "warning": "Если время, отведённое на проверку успело истечь, то посылка стразу станет готовой к выдаче",
      "params": {"package_code": "%s", "from_list": "%s", "status": "new"}}',
      v_object_code,
      v_list_code);
  end if;
  if v_package_status in ('checked') then
    v_actions_list := v_actions_list || 
      format(', "customs_package_receive": {"code": "customs_package_receive", "name": "Выдать груз получателю", "disabled": false,
      "params": {"package_code": "%s", "from_list": "%s"}, 
      "user_params": [{"code": "receiver_code", "description": "Спросите у получателя пароль, который пришёл ему в извещении и грузе (извещение сохранилось в его Важных уведомлениях)", "type": "string", "restrictions": {"min_length": 6}}]}',
      v_object_code,
      v_list_code);
  end if;

  if pp_utils.is_in_group(in_actor_id, 'master') then
    v_actions_list := v_actions_list || 
      format(', "customs_package_delete": {"code": "customs_package_delete", "name": "Удалить", "disabled": false, "warning": "Груз безвозвратно исчезнет из всех списков",
      "params": {"package_code": "%s", "from_list": "%s"}}',
      v_object_code,
      v_list_code);
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
