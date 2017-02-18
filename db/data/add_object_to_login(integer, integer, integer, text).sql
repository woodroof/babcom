-- Function: data.add_object_to_login(integer, integer, integer, text)

-- DROP FUNCTION data.add_object_to_login(integer, integer, integer, text);

CREATE OR REPLACE FUNCTION data.add_object_to_login(
    in_object_id integer,
    in_login_id integer,
    in_user_object_id integer DEFAULT NULL::integer,
    in_reason text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
declare
  v_exists boolean;
begin
  assert in_login_id is not null;
  assert in_object_id is not null;

  perform id
  from data.logins
  where id = in_login_id;

  select true
  into v_exists
  from data.login_objects
  where
    login_id = in_login_id and
    object_id = in_object_id;

  if v_exists is not null then
    raise exception 'Object % is already accessible for login %', in_object_id, in_login_id;
  end if;

  insert into data.login_objects(login_id, object_id, start_time, start_reason, start_object_id)
  values (in_login_id, in_object_id, now(), in_reason, in_user_object_id);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
