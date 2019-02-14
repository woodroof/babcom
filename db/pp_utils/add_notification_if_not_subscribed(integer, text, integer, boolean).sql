-- drop function pp_utils.add_notification_if_not_subscribed(integer, text, integer, boolean);

create or replace function pp_utils.add_notification_if_not_subscribed(in_actor_id integer, in_text text, in_redirect_object integer, in_is_important boolean default false)
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
    perform pp_utils.add_notification(in_actor_id, in_text, in_redirect_object, in_is_important);
  end if;

end;
$$
language plpgsql;
