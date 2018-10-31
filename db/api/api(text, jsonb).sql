-- drop function api.api(text, jsonb);

create or replace function api.api(in_client_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_client_id text;
	v_notification_id text;
  v_message jsonb :=
    jsonb_build_object(
      'type',
      'test',
      'data',
      jsonb_build_object(
        'client_id',
        in_client_id,
        'message',
        in_message));
begin
  for v_client_id in
  (
    select client_id
    from data.connections
  )
  loop
	  insert into data.notifications(message, client_id)
	  values (v_message, v_client_id)
	  returning id into v_notification_id;

	  perform pg_notify('api_channel', v_notification_id);
  end loop;
end;
$$
language 'plpgsql';
