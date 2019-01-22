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
  v_notification_data jsonb;
begin
  for v_diff in
  (
    select
      json.get_integer(value, 'client_id') as client_id,
      (case when value ? 'object' then value->'object' else null end) as object,
      (case when value ? 'list_changes' then value->'list_changes' else null end) as list_changes
    from jsonb_array_elements(v_diffs)
  )
  loop
    v_notification_data := jsonb_build_object('object_id', v_object_code);

    if v_diff.object is not null then
      v_notification_data := v_notification_data || jsonb_build_object('object', v_diff.object);
    end if;

    if v_diff.list_changes is not null then
      v_notification_data := v_notification_data || jsonb_build_object('list_changes', v_diff.list_changes);
    end if;

    perform api_utils.create_notification(v_diff.client_id, null, 'diff', v_notification_data);
  end loop;
end;
$$
language plpgsql;
