-- drop function api.get_notification(text);

create or replace function api.get_notification(in_notification_id text)
returns jsonb
volatile
as
$$
declare
	v_message text;
	v_client_id text;
begin
	delete from data.notifications
	where id = in_notification_id
	returning message, client_id
	into v_message, v_client_id;

	return jsonb_build_object(
		'client_id',
    v_client_id,
		'message',
    v_message);
end;
$$
language 'plpgsql';
