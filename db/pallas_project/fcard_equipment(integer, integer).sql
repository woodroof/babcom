-- drop function pallas_project.fcard_equipment(integer, integer);

create or replace function pallas_project.fcard_equipment(in_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_mine_equipment_json jsonb := data.get_attribute_value_for_share('mine_equipment', 'mine_equipment');
  v_tech_id text;
  v_tech_object jsonb;
  v_tech_type text;
  v_old_equipment_list text := json.get_string_opt(data.get_attribute_value_for_update('equipment', 'equipment_list'), '');
  v_equipment_list text := '';
begin
  for v_tech_id in (select * from jsonb_object_keys(v_mine_equipment_json)) loop
    v_tech_object := json.get_object(v_mine_equipment_json, v_tech_id);
    v_tech_type := json.get_string(v_tech_object, 'type');
    if v_tech_type in ('driller', 'digger', 'buksir', 'dron', 'loader', 'stealer', 'ship', 'train') then
      if not data.is_object_exists('equipment_' || v_tech_id) then
        perform data.create_object(
          'equipment_' || v_tech_id,
          format('[
            {"code": "title", "value": "%s"},
            {"code": "tech_type", "value": "%s"},
            {"code": "tech_broken", "value": "%s"},
            {"code": "tech_qr", "value": "%s"}
            ]',
            v_tech_type,
            v_tech_type,
            case when json.get_boolean(v_tech_object, 'broken') then 'broken' else 'working' end,
            data.get_string_param('objects_url') || 'equipment_' || v_tech_id
          ) ::jsonb,
          'tech') ;
      end if;
      v_equipment_list := v_equipment_list 
        || E'\n' || pp_utils.link('equipment_' || v_tech_id) 
        || ' (broken: ' || json.get_boolean_opt(v_tech_object, 'broken', null) 
        || ', x: ' || json.get_integer_opt(v_tech_object, 'x', -100) 
        || ', y: '|| json.get_integer_opt(v_tech_object, 'y', -100) 
        || ', firm: ' || json.get_string_opt(v_tech_object, 'firm', '-') ||')';
    end if;
  end loop;
  if v_old_equipment_list <> v_equipment_list then
    perform data.set_attribute_value('equipment', 'equipment_list', to_jsonb(v_equipment_list));
  end if;
end;
$$
language plpgsql;
