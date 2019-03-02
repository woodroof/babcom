-- drop function pallas_project.preprocess_joinrpg(jsonb);

create or replace function pallas_project.preprocess_joinrpg(in_value jsonb)
returns jsonb
immutable
as
$$
declare
  v_ret_val jsonb := jsonb '[]';
  v_map jsonb :=
    '{
      "4744": "__comment",
      "4715": "__orgs",
      "4737": "__contracts",
      "4717": "__documents",
      "4716": "__outer_contacts",
      "4714": "__additional_persons",
      "4654": "person_occupation",
      "4652": "description",
      "4628": "system_person_economy_type",
      "4629": "person_state",
      "4633": "person_un_rating",
      "4634": "person_opa_rating",
      "4630": "system_person_deposit_money",
      "4632": "system_money",
      "4635": "system_person_life_support_status",
      "4636": "system_person_health_care_status",
      "4638": "system_person_recreation_status",
      "4639": "system_person_police_status",
      "4640": "system_person_administrative_services_status",
      "4641": "__code",
      "4643": "__login_code",
      "4718": "person_district"
    }';
  v_object_properties integer[] := array[4744, 4715, 4737, 4717, 4716, 4714, 4641, 4643];
  v_process_values integer[] := array[4628, 4629, 4635, 4636, 4638, 4639, 4640, 4718];
  v_to_int_values integer[] := array[4633, 4634, 4630, 4632];
  v_value_map jsonb :=
    jsonb '{
      "4554": "un",
      "4555": "mcr",
      "4556": "asters",
      "4558": "fixed",
      "4559": null,
      "4560": "un_base",
      "4561": "un",
      "4562": "mcr",
      "4563": 0,
      "4564": 1,
      "4565": 2,
      "4566": 3,
      "4567": 0,
      "4568": 1,
      "4569": 2,
      "4570": 3,
      "4571": 0,
      "4572": 1,
      "4573": 2,
      "4574": 3,
      "4575": 0,
      "4576": 1,
      "4577": 2,
      "4578": 3,
      "4579": 0,
      "4580": 1,
      "4581": 2,
      "4582": 3,
      "4635": "sector_A",
      "4636": "sector_B",
      "4637": "sector_C",
      "4638": "sector_D",
      "4639": "sector_E",
      "4640": "sector_F",
      "4641": "sector_G"
    }';
  v_player jsonb;

  v_element jsonb;

  v_field record;
  v_value jsonb;
  v_code jsonb;
  v_attributes jsonb;
begin
  for v_player in
  (
    select value
    from jsonb_array_elements(in_value)
  )
  loop
    v_attributes := jsonb '[]' || jsonb_build_object('code', 'title', 'value', json.get_string(v_player, 'CharacterName'));
    v_element := jsonb '{}';

    for v_field in
    (
      select
        json.get_integer(value, 'ProjectFieldId') id,
        json.get_string(value, 'Value') as value
      from jsonb_array_elements(v_player->'Fields')
    )
    loop
      if array_position(v_process_values, v_field.id) is not null then
        v_value := v_value_map->(v_field.value);
      elsif array_position(v_to_int_values, v_field.id) is not null then
        v_value := v_field.value::integer;
      else
        v_value := to_jsonb(v_field.value);
      end if;

      v_code := v_map->(v_field.id::text);

      if array_position(v_object_properties, v_field.id) is null then
        v_attributes := v_attributes || jsonb_build_object('code', v_code, 'value', v_value);
      else
        v_element := v_element || jsonb_build_object(json.get_string(v_code), v_value);
      end if;
    end loop;

    v_element := v_element || jsonb_build_object('attributes', v_attributes);

    v_ret_val := v_ret_val || v_element;
  end loop;

  return v_ret_val;
end;
$$
language plpgsql;
