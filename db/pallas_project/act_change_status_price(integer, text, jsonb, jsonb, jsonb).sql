-- drop function pallas_project.act_change_status_price(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_change_status_price(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_type text := json.get_string(in_params);
  v_index integer := json.get_integer(in_user_params, 'index');
  v_price integer := json.get_integer(in_user_params, 'price');
  v_full_name text := v_type || '_status_prices';

  v_prices jsonb;
  v_notified boolean;
begin
  select value
  into v_prices
  from data.params
  where code = v_full_name
  for update;

  v_prices := jsonb_set(v_prices, array[(v_index - 1)::text], to_jsonb(v_price));

  update data.params
  set value = v_prices
  where code = v_full_name;

  v_notified := data.change_current_object(in_client_id, in_request_id, data.get_object_id('prices'), jsonb_build_object(v_full_name, v_prices));

  if not v_notified then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
