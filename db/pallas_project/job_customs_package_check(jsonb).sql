-- drop function pallas_project.job_customs_package_check(jsonb);

create or replace function pallas_project.job_customs_package_check(in_params jsonb)
returns void
volatile
as
$$
declare
  v_package_code text := json.get_string(in_params, 'package_code');
  v_from_list text := json.get_string(in_params, 'from_list');
  v_check_type text := json.get_string(in_params, 'check_type');
  v_package_id integer := data.get_object_id(v_package_code);

  v_customs_id integer := data.get_object_id(v_from_list);
  v_customs_new_id integer := data.get_object_id('customs_new');
  v_package_status text := json.get_string(data.get_attribute_value_for_update(v_package_id, 'package_status'));
  v_system_customs_checking boolean := json.get_boolean_opt(data.get_attribute_value_for_update(v_customs_new_id, 'system_customs_checking'), false);
  v_system_package_reactions text[] := json.get_string_array(data.get_attribute_value(v_package_id, 'system_package_reactions'));
  v_package_cheked_reactions jsonb := coalesce(data.get_attribute_value_for_update(v_package_id, 'package_cheked_reactions'), jsonb '{}');

  v_check_result boolean;
  v_object_changes jsonb := jsonb '[]';
  v_changes jsonb := jsonb '[]';
begin
  if v_package_status = 'checking' then
    if v_check_type = 'life' and data.get_raw_attribute_value(v_package_id, 'package_what') = jsonb '"кот Шрёдингера (муляж)"' then
      if random.random_integer(0, 1) = 0 then
        v_object_changes := v_object_changes || data.attribute_change2jsonb('package_what', jsonb '"мёртвый кот (муляж)"');
        v_check_result := false;
      else
        v_object_changes :=
          v_object_changes ||
          data.attribute_change2jsonb('package_what', jsonb '"кот (муляж)"');
        v_check_result := false;
      end if;
    elsif array_position(v_system_package_reactions, v_check_type) is not null then
      v_check_result := true;
    else
      v_check_result := false;
    end if;
    v_package_cheked_reactions := jsonb_set(v_package_cheked_reactions, array[v_check_type], to_jsonb(v_check_result));

    v_changes :=
      v_changes ||
      jsonb_build_object(
        'id',
        v_package_id,
        'changes',
        v_object_changes ||
        data.attribute_change2jsonb('package_cheked_reactions', v_package_cheked_reactions) ||
        data.attribute_change2jsonb('package_status', '"new"'));
  end if;

  v_changes :=
    v_changes ||
    jsonb_build_object(
      'id',
      v_customs_new_id,
      'changes',
      jsonb '[]' || data.attribute_change2jsonb('system_customs_checking', null));
  if v_customs_new_id <> v_customs_id then
    v_changes :=
      v_changes ||
      jsonb_build_object(
        'id',
        v_customs_id,
        'changes',
        jsonb '[]' || data.attribute_change2jsonb('system_customs_checking', null));
  end if;

  perform data.process_diffs_and_notify(data.change_objects(v_changes));
end;
$$
language plpgsql;
