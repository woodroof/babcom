-- drop function test_project.next_or_do_nothing_list_action(integer, text, integer, integer);

create or replace function test_project.next_or_do_nothing_list_action(in_client_id integer, in_request_id text, in_object_id integer, in_list_object_id integer)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_object_code text := data.get_object_code(in_object_id);
  v_list_object_code text := data.get_object_code(in_list_object_id);
  v_list_object_title text := json.get_string_opt(data.get_attribute_value(in_list_object_id, 'title', v_actor_id), null);
begin
  assert in_request_id is not null;

  if v_list_object_title = 'Далее' then
    perform api_utils.create_open_object_action_notification(
      in_client_id,
      in_request_id,
      test_project.next_code(v_object_code));
  else
    perform api_utils.create_ok_notification(in_client_id, in_request_id);
  end if;
end;
$$
language plpgsql;
