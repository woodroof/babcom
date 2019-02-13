-- drop function pallas_project.lef_do_nothing(integer, text, integer, integer);

create or replace function pallas_project.lef_do_nothing(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
begin
  assert in_request_id is not null;
  assert in_list_object_id is not null;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
