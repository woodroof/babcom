-- drop function pallas_project.act_change_coin_price(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_change_coin_price(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_price integer := json.get_integer(in_user_params, 'price');
  v_notified boolean;
begin
  update data.params
  set value = to_jsonb(v_price)
  where code = 'coin_price';

  v_notified := data.change_current_object(in_client_id, in_request_id, data.get_object_id('prices'), jsonb_build_object('coin_price', v_price));

  if not v_notified then
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
