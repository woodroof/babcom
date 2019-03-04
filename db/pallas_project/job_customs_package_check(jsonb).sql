-- drop function pallas_project.job_customs_package_check(jsonb);

create or replace function pallas_project.job_customs_package_check(in_params jsonb)
returns void
volatile
as
$$
declare
  v_package_code text := json.get_string(in_params, 'package_code');
  v_check_type text := json.get_string(in_params, 'check_type');
  v_package_id integer := data.get_object_id(v_package_code);

  v_custons_new_id integer := data.get_object_id('customs_new');
  v_package_status text := json.get_string(data.get_attribute_value_for_update(v_package_id, 'package_status'));
  v_system_customs_checking boolean := json.get_boolean_opt(data.get_attribute_value_for_update(v_custons_new_id, 'system_customs_checking'), false);
  v_system_package_reactions text[] := json.get_string_array(data.get_attribute_value(v_package_id, 'system_package_reactions'));
  v_package_cheked_reactions jsonb := coalesce(data.get_attribute_value_for_update(v_package_id, 'package_cheked_reactions'), jsonb '{}');

  v_check_result boolean;
  v_change jsonb[] := array[]::jsonb[];
begin
  if v_package_status = 'checking' then
    if array_position(v_system_package_reactions, v_check_type) is not null then
      v_check_result := true;
    else
      v_check_result := false;
    end if;
    v_package_cheked_reactions := jsonb_set(v_package_cheked_reactions, array[v_check_type], to_jsonb(v_check_result));

    v_change := array_append(v_change, data.attribute_change2jsonb('package_cheked_reactions', v_package_cheked_reactions));
    v_change := array_append(v_change, data.attribute_change2jsonb('package_status', '"new"'));
    perform data.change_object_and_notify(v_package_id, 
                                          to_jsonb(v_change),
                                          null);
  end if;

  v_change := array[]::jsonb[];
  v_change := array_append(v_change, data.attribute_change2jsonb('system_customs_checking', null));
  perform data.change_object_and_notify(v_custons_new_id, 
                                        to_jsonb(v_change),
                                        null);

end;
$$
language plpgsql;
