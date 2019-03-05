-- drop function pallas_project.get_future_packages(integer);

create or replace function pallas_project.get_future_packages(in_level integer)
returns jsonb
volatile
as
$$
declare
  v_package_id integer;
  v_package_code text;
  v_customs_id integer := data.get_object_id('customs_future');
  v_content_future text[] := json.get_string_array(data.get_raw_attribute_value_for_update(v_customs_id, 'content', null));
  v_master_id integer := data.get_object_id('master');
  v_ships integer;
  v_packages integer[] := array[]::integer[];
  v_content text[] := array[]::text[];
begin
  for v_package_code in select unnest(v_content_future) loop
    v_package_id := data.get_object_id(v_package_code);
    if json.get_integer_opt(data.get_attribute_value(v_package_id, 'package_receiver_status'), 0) = in_level then
      v_ships := json.get_integer_opt(data.get_attribute_value(v_package_id, 'package_ships_before_come', v_master_id), 1);
      if v_ships= 1 then
        v_packages := array_append(v_packages, v_package_id);
        v_content := array_append(v_content, v_package_code);
        v_content_future := array_remove(v_content_future, v_package_code);
        perform data.change_object_and_notify(
          v_package_id, 
          jsonb_build_array(
            data.attribute_change2jsonb('package_arrival_time', to_jsonb(pp_utils.format_date(clock_timestamp()))),
            data.attribute_change2jsonb('package_ships_before_come', null, v_master_id)));
      elsif v_ships > 1 then
        perform data.change_object_and_notify(v_package_id, jsonb_build_array(data.attribute_change2jsonb('package_ships_before_come', to_jsonb(v_ships - 1), v_master_id)));
      end if;
    end if;
  end loop;
  perform data.change_object_and_notify(v_customs_id, jsonb_build_array(data.attribute_change2jsonb('content', to_jsonb(v_content_future))));
  return jsonb_build_object('packages', v_packages, 'content', v_content);
end;
$$
language plpgsql;
