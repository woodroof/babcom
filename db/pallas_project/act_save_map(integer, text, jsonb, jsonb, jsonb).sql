-- drop function pallas_project.act_save_map(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_save_map(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_map text := json.get_string(in_user_params, 'map');
  v_notified boolean;
begin
  v_notified :=
    data.change_current_object(
      in_client_id,
      in_request_id,
      data.get_object_id('mine_map'),
      jsonb_build_object('mine_map', v_map));
  if not v_notified then
    perform pallas_project.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
