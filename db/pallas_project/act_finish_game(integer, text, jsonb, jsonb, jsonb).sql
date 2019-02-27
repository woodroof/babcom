-- drop function pallas_project.act_finish_game(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_finish_game(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_confirm text := json.get_string(in_user_params, 'confirm');
  v_param jsonb;
  v_person_id integer;
  v_value integer;
begin
  if v_confirm != 'ДА' then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Не в этот раз', 'Игра продолжается!');
    return;
  end if;

  select value
  into v_param
  from data.params
  where code = 'game_in_progress'
  for update;

  if v_param != jsonb 'true' then
    perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Ошибка', 'Игра уже завершена!');
    return;
  end if;

  update data.params
  set value = jsonb 'false'
  where code = 'game_in_progress';

  for v_person_id in
  (
    select object_id
    from data.object_objects
    where
      parent_object_id = data.get_object_id('all_person') and
      object_id != parent_object_id
  )
  loop
    perform pp_utils.add_notification(v_person_id, E'Игра завершена!\nБазовые функции ещё будут работать некоторое время, но экономические циклы более не меняются.\nВсем спасибо за участие!');
  end loop;

  -- Перегенерируем меню
  v_value := json.get_integer(data.get_attribute_value_for_update('menu', 'force_object_diff'));
  perform data.change_object_and_notify(data.get_object_id('menu'), format('{"force_object_diff": %s}', v_value + 1)::jsonb);

  perform pallas_project.send_to_master_chat('Игра завершена');

  perform api_utils.create_show_message_action_notification(in_client_id, in_request_id, 'Игра завершена', 'Иди отдыхай уже!');
end;
$$
language plpgsql;
