-- drop function pallas_project.act_finish_lottery(integer, text, jsonb, jsonb, jsonb);

create or replace function pallas_project.act_finish_lottery(in_client_id integer, in_request_id text, in_params jsonb, in_user_params jsonb, in_default_params jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_lottery_id integer := data.get_object_id('lottery');
  v_lottery_status text := json.get_string(data.get_attribute_value_for_update(v_lottery_id, 'lottery_status'));
  v_menu_attr integer := json.get_integer(data.get_attribute_value_for_update('menu', 'force_object_diff'));
  v_lottery_owner text := json.get_string_opt(data.get_attribute_value_for_share(v_lottery_id, 'system_lottery_owner'), null);
  v_total_ticket_count integer;
  v_win_ticket_num integer;
  v_current_ticket_num integer := 0;
  v_aster record;
  v_aster_id integer;
  v_text text;
  v_player_id integer;
  v_notified boolean;
begin
  assert in_request_id is not null;
  assert pp_utils.is_in_group(v_actor_id, 'master') or v_actor_id = data.get_object_id(v_lottery_owner);

  if v_lottery_status = 'active' then
    -- Ищем победителя
    select sum(ticket_count)
    into v_total_ticket_count
    from
    (
      select json.get_integer(value) ticket_count
      from data.attribute_values
      where
        object_id = v_lottery_id and
        attribute_id = data.get_attribute_id('lottery_ticket_count') and
        value_object_id is not null
      for share
    ) a;

    v_win_ticket_num := random.random_integer(1, v_total_ticket_count);

    for v_aster in
    (
      select value_object_id, json.get_integer(value) ticket_count
      from data.attribute_values
      where
        object_id = v_lottery_id and
        attribute_id = data.get_attribute_id('lottery_ticket_count') and
        value_object_id is not null
    )
    loop
      v_current_ticket_num := v_current_ticket_num + v_aster.ticket_count;
      if v_current_ticket_num >= v_win_ticket_num then
        v_aster_id := v_aster.value_object_id;
        exit;
      end if;
    end loop;

    v_text := 'Лотерея завершена. Победитель: ' || pp_utils.link(v_aster_id, null);

    -- Отправляем уведомление игрокам
    for v_player_id in
    (
      select object_id
      from data.object_objects
      where
        parent_object_id = data.get_object_id('player') and
        object_id != parent_object_id and
        object_id != v_aster_id
    )
    loop
      perform pp_utils.add_notification(v_player_id, v_text, v_lottery_id, true);
    end loop;

    -- Отправляем уведомление победителю
    perform pp_utils.add_notification(v_aster_id, 'Поздравляем, вы выиграли в лотерее и получаете гражданство ООН!', v_lottery_id, true);

    -- Меняем экономику на гражданина
    perform pallas_project.change_aster_to_un(v_aster_id, v_actor_id);

    -- Завершаем лотерею
    v_notified :=
      data.change_current_object(
        in_client_id,
        in_request_id,
        v_lottery_id,
        format('{"lottery_status": "finished", "lottery_winner": "%s"}', data.get_object_code(v_aster_id))::jsonb,
        'Finish lottery action');
    assert v_notified;
    perform data.change_object_and_notify(
      data.get_object_id('menu'),
      jsonb_build_object('force_object_diff', v_menu_attr + 1),
      v_actor_id,
      'Finish lottery action');
    return;
  end if;

  perform api_utils.create_ok_notification(
    in_client_id,
    in_request_id);
end;
$$
language plpgsql;
