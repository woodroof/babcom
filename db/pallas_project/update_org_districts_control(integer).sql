-- drop function pallas_project.update_org_districts_control(integer);

create or replace function pallas_project.update_org_districts_control(in_org_id integer)
returns void
volatile
as
$$
declare
  v_org_code text := data.get_object_code(in_org_id);
  v_control_code text := pallas_project.org_code_to_control(v_org_code);
  v_control_code_jsonb jsonb := to_jsonb(v_control_code);
  v_district_codes text[] := json.get_string_array(data.get_raw_attribute_value('districts', 'content'));
  v_district_control_attr_id integer := data.get_attribute_id('district_control');
  v_org_districts_control_attr_id integer := data.get_attribute_id('org_districts_control');
  v_org_districts_control jsonb;
begin
  select jsonb_agg(o.code)
  into v_org_districts_control
  from unnest(v_district_codes) a(value)
  join data.objects o on
    o.code = a.value
  join data.attribute_values av on
    av.object_id = o.id and
    av.attribute_id = v_district_control_attr_id and
    av.value = v_control_code_jsonb;

  perform data.change_object_and_notify(
    in_org_id,
    jsonb '[]' ||
    data.attribute_change2jsonb('system_org_districts_control', v_org_districts_control) ||
    data.attribute_change2jsonb(v_org_districts_control_attr_id, v_org_districts_control, 'master') ||
    data.attribute_change2jsonb(v_org_districts_control_attr_id, v_org_districts_control, v_org_code || '_head') ||
    data.attribute_change2jsonb(v_org_districts_control_attr_id, v_org_districts_control, v_org_code || '_economist'));
end;
$$
language plpgsql;
