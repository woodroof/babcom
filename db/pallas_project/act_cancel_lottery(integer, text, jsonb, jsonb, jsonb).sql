-- drop function pallas_project.act_cancel_lottery(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_cancel_lottery(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
begin
  assert in_request_id is not null;

  -- todo

  perform api_utils.create_ok_notification(
    in_client_id,
    in_request_id);
end;
$$
language plpgsql;
