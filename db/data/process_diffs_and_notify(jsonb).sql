-- drop function data.process_diffs_and_notify(jsonb);

create or replace function data.process_diffs_and_notify(in_diffs jsonb)
returns void
volatile
as
$$
declare
  v_diff record;
  v_notification_data jsonb;
begin
  assert json.is_object_array(in_diffs);

  for v_diff in
  (
    select
      json.get_string(value, 'object_id') as object_id,
      json.get_integer(value, 'client_id') as client_id,
      (case when value ? 'object' then value->'object' else null end) as object,
      (case when value ? 'list_changes' then value->'list_changes' else null end) as list_changes
    from jsonb_array_elements(in_diffs)
  )
  loop
    v_notification_data := jsonb_build_object('object_id', v_diff.object_id);

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
