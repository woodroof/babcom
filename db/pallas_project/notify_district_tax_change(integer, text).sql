-- drop function pallas_project.notify_district_tax_change(integer, text);

create or replace function pallas_project.notify_district_tax_change(in_district_id integer, in_message text)
returns void
volatile
as
$$
declare
  v_district_population jsonb := data.get_raw_attribute_value_for_share(in_district_id, 'content');
  v_system_person_economy_type_attr_id integer := data.get_attribute_id('system_person_economy_type');
  v_message text := 'У вас изменилась ставка налога ' || in_message;
  v_person_id integer;
begin
  for v_person_id in
  (
    select o.id
    from jsonb_array_elements(v_district_population) e
    join data.objects o on
      o.code = json.get_string(e.value)
    join data.attribute_values av on
      av.object_id = o.id and
      av.attribute_id = v_system_person_economy_type_attr_id and
      av.value in (jsonb '"asters"', jsonb '"mcr"')
  )
  loop
    perform pp_utils.add_notification(
      v_person_id,
      v_message,
      in_district_id,
      true);
  end loop;
end;
$$
language plpgsql;
