-- drop function pallas_project.act_save_map(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_save_map(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_map text := json.get_string(in_user_params, 'map');
begin
  perform data.change_object_and_notify(
      data.get_object_id('mine_map'),
      jsonb_build_object('mine_map', v_map));
  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
