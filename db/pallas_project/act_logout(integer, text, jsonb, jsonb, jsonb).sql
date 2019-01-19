-- drop function pallas_project.act_logout(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_logout(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_login_id integer := data.get_param('default_login_id');

begin
  assert in_request_id is not null;

  if v_login_id is not null then
  -- Заменим логин
    perform data.set_login(in_client_id, v_login_id);
    -- И отправим новый список акторов
    perform api_utils.process_get_actors_message(in_client_id, in_request_id);
  else
  -- Вернём ошибку, если на нашли логин в табличке
    perform api_utils.create_notification(
      in_client_id,
      in_request_id,
      'action',
      format('{"action": "show_message ", "action_data": {"title": "%s", "message": "%s"}}', 'Ошибка', 'Пароль не найден')::jsonb); 
  end if;
end;
$$
language 'plpgsql';
