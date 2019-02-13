-- drop function pp_utils.is_actor_subscribed(integer, integer);

create or replace function pp_utils.is_actor_subscribed(in_actor_id integer, in_object integer)
returns boolean
stable
as
$$
declare
  v_exists integer;
begin
  -- Ищем подписку на этот объект у этого актора
  select count(s.object_id) into v_exists
  from data.clients c
  inner join data.client_subscriptions s on s.client_id = c.id and s.object_id = in_object
  where c.actor_id = in_actor_id;

  if v_exists > 0 then
    return true;
  else 
    return false;
  end if;
end;
$$
language plpgsql;
