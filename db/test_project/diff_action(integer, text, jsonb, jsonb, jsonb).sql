-- drop function test_project.diff_action(integer, text, jsonb, jsonb, jsonb);

create or replace function test_project.diff_action(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_title text := test_project.next_code(json.get_string(in_params, 'title'));
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_changes jsonb;
  v_change record;
  v_message_sent boolean := false;
begin
  assert in_request_id is not null;
  assert test_project.is_user_params_empty(in_user_params);
  assert in_default_params is null;

  v_changes :=
    data.change_object(
      v_object_id,
      format(
        '[{"id": %s, "value": "%s"}, {"id": %s, "value": "%s"}]',
        data.get_attribute_id('title'),
        v_title,
        data.get_attribute_id('description'),
-- todo Описание для следующего теста
'Ура!')::jsonb,
      v_actor_id);
  for v_change in
  (
    select
      json.get_integer(value, 'client_id') as client_id,
      json.get_object(value, 'object') as object
    from jsonb_array_elements(v_changes)
  )
  loop
    if v_change.client_id = in_client_id then
      assert v_message_sent is false;

      v_message_sent := true;

      perform api_utils.create_notification(v_change.client_id, in_request_id, 'diff', jsonb_build_object('object_id', v_object_id, 'object', v_change.object));
    else
      perform api_utils.create_notification(v_change.client_id, null, 'diff', jsonb_build_object('object_id', v_object_id, 'object', v_change.object));
    end if;
  end loop;

  if v_message_sent is false then
    perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
  end if;
end;
$$
language 'plpgsql';
