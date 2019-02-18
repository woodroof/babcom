-- drop function pallas_project.actgenerator_notifications(integer, integer);

create or replace function pallas_project.actgenerator_notifications(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
begin
  return jsonb '{"clear_notifications": {"code": "clear_notifications", "name": "Очистить", "disabled": false, "params": null}}';
end;
$$
language plpgsql;
