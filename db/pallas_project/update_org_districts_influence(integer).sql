-- drop function pallas_project.update_org_districts_influence(integer);

create or replace function pallas_project.update_org_districts_influence(in_org_id integer)
returns void
volatile
as
$$
declare
  v_org_code text := data.get_object_code(in_org_id);
  v_control_code text := pallas_project.org_code_to_control(v_org_code);
  v_district_codes text[] := json.get_string_array(data.get_raw_attribute_value('districts', 'content'));
  v_district_influence_attr_id integer := data.get_attribute_id('district_influence');
  v_org_districts_influence_attr_id integer := data.get_attribute_id('org_districts_influence');
  v_org_districts_influence jsonb;
begin
  select jsonb_object_agg(o.code, json.get_integer(av.value, v_control_code))
  into v_org_districts_influence
  from unnest(v_district_codes) a(value)
  join data.objects o on
    o.code = a.value
  join data.attribute_values av on
    av.object_id = o.id and
    av.attribute_id = v_district_influence_attr_id;

  perform data.change_object_and_notify(
    in_org_id,
    jsonb '[]' ||
    data.attribute_change2jsonb('system_org_districts_influence', v_org_districts_influence) ||
    data.attribute_change2jsonb(v_org_districts_influence_attr_id, v_org_districts_influence, 'master') ||
    data.attribute_change2jsonb(v_org_districts_influence_attr_id, v_org_districts_influence, v_org_code || '_head') ||
    data.attribute_change2jsonb(v_org_districts_influence_attr_id, v_org_districts_influence, v_org_code || '_economist'));
end;
$$
language plpgsql;
