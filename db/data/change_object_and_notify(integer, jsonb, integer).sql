-- drop function data.change_object_and_notify(integer, jsonb, integer);

create or replace function data.change_object_and_notify(in_object_id integer, in_changes jsonb, in_actor_id integer default null::integer)
returns void
volatile
as
$$
declare
  v_diffs jsonb := data.change_object(in_object_id, in_changes, in_actor_id);
  v_diff record;
  v_object_code text := data.get_object_code(in_object_id);
begin
  for v_diff in
  (
    select
      json.get_integer(value, 'client_id') as client_id,
      json.get_object(value, 'object') as object
    from jsonb_array_elements(v_diffs)
  )
  loop
    perform api_utils.create_notification(v_diff.client_id, null, 'diff', jsonb_build_object('object_id', v_object_code, 'object', v_diff.object));
  end loop;
end;
$$
language 'plpgsql';
