-- drop function pallas_project.add_notification_if_not_subscribed(integer, text, integer);

create or replace function pallas_project.add_notification_if_not_subscribed(in_actor_id integer, in_text text, in_redirect_object integer)
returns void
volatile
as
$$
declare
  v_exists integer;
begin
  -- Ищем подписку на этот объект у этого актора
  select count(s.object_id) into v_exists
  from data.clients c
  inner join data.client_subscriptions s on s.client_id = c.id and s.object_id = in_redirect_object
  where c.actor_id = in_actor_id;

  if v_exists = 0 then
    perform pallas_project.add_notification(in_actor_id, in_text, in_redirect_object);
  end if;

end;
$$
language plpgsql;
