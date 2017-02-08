-- Function: data.remove_object_from_login(integer, integer, integer, text)

-- DROP FUNCTION data.remove_object_from_login(integer, integer, integer, text);

CREATE OR REPLACE FUNCTION data.remove_object_from_login(
    in_object_id integer,
    in_login_id integer,
    in_user_object_id integer DEFAULT NULL::integer,
    in_reason text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
declare
  v_login_object_info record;
begin
  assert in_login_id is not null;
  assert in_object_id is not null;

  select id, start_time, start_reason, start_object_id
  into v_login_object_info
  from data.login_objects
  where
    login_id = in_login_id and
    object_id = in_object_id
  for update;

  if v_login_object_info is null then
    raise exception 'Object % is not accessible for login %', in_object_id, in_login_id;
  end if;

  insert into data.login_objects_journal(login_id, object_id, start_time, start_reason, start_object_id, end_time, end_reason, end_object_id)
  values (
    in_login_id,
    in_object_id,
    v_login_object_info.start_time,
    v_login_object_info.start_reason,
    v_login_object_info.start_object_id,
    now(),
    in_reason,
    in_user_object_id);

  delete from data.login_objects
  where id = v_login_object_info.id;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
