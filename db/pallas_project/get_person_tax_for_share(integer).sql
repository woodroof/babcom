-- drop function pallas_project.get_person_tax_for_share(integer);

create or replace function pallas_project.get_person_tax_for_share(in_person_id integer)
returns jsonb
volatile
as
$$
declare
  v_district_id integer := data.get_object_id(json.get_string(data.get_raw_attribute_value_for_share(in_person_id, 'person_district')));
  v_district_tax integer := json.get_integer(data.get_raw_attribute_value_for_share(v_district_id, 'district_tax'));
begin
  return v_district_tax;
end;
$$
language plpgsql;
