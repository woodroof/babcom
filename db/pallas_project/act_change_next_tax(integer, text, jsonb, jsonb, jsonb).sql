-- drop function pallas_project.act_change_next_tax(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_change_next_tax(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_tax integer := json.get_bigint(in_user_params, 'tax');
  v_object_code text := json.get_string(in_params);
  v_notified boolean;
begin
  assert v_tax >= 0 and v_tax < 100;

  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      data.get_object_id(v_object_code),
      format(
        '[
          {"code": "system_org_next_tax", "value": %s},
          {"code": "org_next_tax", "value": %s, "value_object_code": "master"},
          {"code": "org_next_tax", "value": %s, "value_object_code": "%s_head"},
          {"code": "org_next_tax", "value": %s, "value_object_code": "%s_economist"}
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
end;
$$
language plpgsql;
