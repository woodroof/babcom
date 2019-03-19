-- drop function pallas_project.actgenerator_med_health(integer, integer);

create or replace function pallas_project.actgenerator_med_health(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions_list text := '';
  v_is_master boolean;
  v_person_code text := replace(data.get_object_code(in_object_id),'_med_health','');
  v_med_health jsonb := data.get_attribute_value_for_share(in_object_id, 'med_health');
  v_level integer;

begin
  assert in_actor_id is not null;

  v_is_master := pp_utils.is_in_group(in_actor_id, 'master');

  select x.level into v_level
  from jsonb_to_record(jsonb_extract_path(v_med_health, 'wound')) as x(level integer);

  v_actions_list := v_actions_list || 
        format(', "med_light_wound": {"code": "med_set_disease_level", "name": "Получил лёгкое ранение (конечности)", "disabled": %s, "warning": "Вы уверены, что получили ранение?",'||
                '"params": {"person_code": "%s", "disease": "wound", "level": 1}}',
                case when coalesce(v_level, 0) < 1 then 'false' else 'true' end,
                v_person_code);
  v_actions_list := v_actions_list || 
        format(', "med_heavy_wound": {"code": "med_set_disease_level", "name": "Получил тяжёлое ранение (корпус)", "disabled": %s, "warning": "Вы уверены, что получили ранение?",'||
                '"params": {"person_code": "%s", "disease": "wound", "level": 2}}',
                case when coalesce(v_level, 0) < 2 then 'false' else 'true' end,
                v_person_code);

  select x.level into v_level
  from jsonb_to_record(jsonb_extract_path(v_med_health, 'radiation')) as x(level integer);

  v_actions_list := v_actions_list || 
        format(', "med_irradiated": {"code": "med_set_disease_level", "name": "Получил дозу облучения", "disabled": %s, "warning": "Вы уверены, что получили дозу облучения?",'||
                '"params": {"person_code": "%s", "disease": "radiation", "level": 1}}',
                case when coalesce(v_level, 0) < 1 then 'false' else 'true' end,
                v_person_code);

  if v_is_master then
    select x.level into v_level
    from jsonb_to_record(jsonb_extract_path(v_med_health, 'asthma')) as x(level integer);

    v_actions_list := v_actions_list || 
          format(', "med_add_asthma": {"code": "med_set_disease_level", "name": "Астма", "disabled": %s,'||
                  '"params": {"person_code": "%s", "disease": "asthma", "level": 1}}',
                  case when coalesce(v_level, 0) < 1 then 'false' else 'true' end,
                  v_person_code);

    select x.level into v_level
    from jsonb_to_record(jsonb_extract_path(v_med_health, 'rio_miamore')) as x(level integer);
    v_actions_list := v_actions_list || 
          format(', "med_add_rio_miamore": {"code": "med_set_disease_level", "name": "Вирус Рио Миаморе", "disabled": %s,'||
                  '"params": {"person_code": "%s", "disease": "rio_miamore", "level": 1}}',
                  case when coalesce(v_level, 0) < 1 then 'false' else 'true' end,
                  v_person_code);

    select x.level into v_level
    from jsonb_to_record(jsonb_extract_path(v_med_health, 'addiction')) as x(level integer);
    v_actions_list := v_actions_list || 
          format(', "med_add_addiction": {"code": "med_set_disease_level", "name": "Зависимость от стимулятора", "disabled": %s,'||
                  '"params": {"person_code": "%s", "disease": "addiction", "level": 1}}',
                  case when coalesce(v_level, 0) < 1 then 'false' else 'true' end,
                  v_person_code);

    select x.level into v_level
    from jsonb_to_record(jsonb_extract_path(v_med_health, 'genetic')) as x(level integer);
    v_actions_list := v_actions_list || 
          format(', "med_add_genetic": {"code": "med_set_disease_level", "name": "Генетическое заболевание", "disabled": %s,'||
                  '"params": {"person_code": "%s", "disease": "genetic", "level": 1}}',
                  case when coalesce(v_level, 0) < 1 then 'false' else 'true' end,
                  v_person_code);
  end if;

  return jsonb ('{'||trim(v_actions_list,',')||'}');
end;
$$
language plpgsql;
