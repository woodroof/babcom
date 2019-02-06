-- drop function pallas_project.act_login(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_login(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_password text := json.get_string(in_user_params, 'password');
  v_login_id integer;

begin
  assert in_request_id is not null;
  assert in_user_params is not null;

  select id into v_login_id from data.logins where code = v_password;

  if v_login_id is not null then
  -- Заменим логин
    perform data.log('info', format('Set login %s for client %s (password: %s)', v_login_id, in_client_id, v_password));
    perform data.set_login(in_client_id, v_login_id);
    -- И отправим новый список акторов
    perform api_utils.process_get_actors_message(in_client_id, in_request_id);
  else
  -- Вернём ошибку, если на нашли логин в табличке
    perform data.log('warning', format('Invalid password %s (client: %s)', v_password, in_client_id));
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Пароль не найден')::jsonb); 
  end if;
end;
$$
language plpgsql;
