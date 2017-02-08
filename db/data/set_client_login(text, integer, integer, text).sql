-- Function: data.set_client_login(text, integer, integer, text)

-- DROP FUNCTION data.set_client_login(text, integer, integer, text);

CREATE OR REPLACE FUNCTION data.set_client_login(
    in_client text,
    in_login_id integer,
    in_user_object_id integer DEFAULT NULL::integer,
    in_reason text DEFAULT NULL::text)
  RETURNS void AS
$BODY$
declare
  v_client_login_info record;
begin
  assert in_client is not null;

  select id, login_id, start_time, start_reason, start_object_id
  into v_client_login_info
  from data.client_login
  where client = in_client
  for update;

  if
    (
      in_login_id is null and
      v_client_login_info is null
    ) or
    in_login_id = v_client_login_info.login_id
  then
    return;
  end if;

  loop
    if not v_client_login_info is null then
      exit;
    end if;

    begin
      insert into data.client_login(
        client,
        login_id,
        start_time,
        start_reason,
        start_object_id)
      values (
        in_client,
        in_login_id,
        clock_timestamp(),
        in_reason,
        in_user_object_id);

      return;
    exception when unique_violation then
      select id, login_id, start_time, start_reason, start_object_id
      into v_client_login_info
      from data.client_login
      where client = in_client
      for update;
    end;
  end loop;

  insert into data.client_login_journal(
    client,
    login_id,
    start_time,
    start_reason,
    start_object_id,
    end_time,
    end_reason,
    end_object_id)
  values (
    in_client,
    v_client_login_info.login_id,
    v_client_login_info.start_time,
    v_client_login_info.start_reason,
    v_client_login_info.start_object_id,
    clock_timestamp(),
    in_reason,
    in_user_object_id);

  if in_login_id is null then
    delete from data.client_login
    where id = v_client_login_info.id;
  else
    update data.client_login
    set
      login_id = in_login_id,
      start_time = clock_timestamp(),
      start_reason = in_reason,
      start_object_id = in_user_object_id
    where id = v_client_login_info.id;
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
