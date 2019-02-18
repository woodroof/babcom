-- drop function pallas_project.actgenerator_notifications_content(integer, integer, integer);

create or replace function pallas_project.actgenerator_notifications_content(in_object_id integer, in_list_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
begin
  return format('{"remove_notification": {"code": "remove_notification", "name": "Удалить", "disabled": false, "params": "%s"}}', data.get_object_code(in_list_object_id))::jsonb;
end;
$$
language plpgsql;
