-- drop function pallas_project.act_change_current_tax(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_change_current_tax(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_tax integer := json.get_bigint(in_user_params, 'tax');
  v_object_code text := json.get_string(in_params);
  v_object_id integer := data.get_object_id(v_object_code);
  v_districts jsonb := data.get_attribute_value_for_share(v_object_id, 'system_org_districts_control');
  v_notified boolean;
  v_district text;
begin
  assert v_tax >= 0 and v_tax < 100;

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      v_object_id,
      format(
        '[
          {"code": "system_org_tax", "value": %s},
          {"code": "org_tax", "value": %s, "value_object_code": "master"},
          {"code": "org_tax", "value": %s, "value_object_code": "%s_head"},
          {"code": "org_tax", "value": %s, "value_object_code": "%s_economist"}
        ]',
        v_tax,
        v_tax,
        v_tax,
        v_object_code,
        v_tax,
        v_object_code)::jsonb);
  -- Та же ставка
  if not v_notified then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;

  for v_district in
  (
    select json.get_string(value)
    from jsonb_array_elements(v_districts)
  )
  loop
    perform data.change_object_and_notify(
      data.get_object_id(v_district),
      format(
        '{
          "district_tax": %s
        }',
        v_tax)::jsonb);
  end loop;
end;
$$
language plpgsql;
