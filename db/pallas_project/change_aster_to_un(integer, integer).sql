-- drop function pallas_project.change_aster_to_un(integer, integer);

create or replace function pallas_project.change_aster_to_un(in_aster_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_base_rating integer := data.get_integer_param('base_un_rating');
  v_life_support_prices integer[] := data.get_integer_array_param('life_support_status_prices');
  v_person_economy_type jsonb := data.get_attribute_value_for_update(in_aster_id, 'system_person_economy_type');
  v_aster_code text := data.get_object_code(in_aster_id);
  v_contracts text[] := json.get_string_array(data.get_raw_attribute_value_for_share(v_aster_code || '_contracts', 'content'));
  v_reason text := 'Смена гражданства';
  v_un_hints_id integer;
  v_contract_id integer;
begin
  assert v_person_economy_type = jsonb '"asters"';

  -- Начисление коинов
  perform pallas_project.change_coins(in_aster_id, pallas_project.un_rating_to_coins(v_base_rating) - v_life_support_prices[1], in_actor_id, v_reason);
  -- Сброс статусов следующего цикла
  perform data.change_object_and_notify(
    data.get_object_id(v_aster_code || '_next_statuses'),
    '[
      {"code": "money"},
      {"code": "life_support_next_status", "value": 1},
      {"code": "health_care_next_status", "value": 0},
      {"code": "recreation_next_status", "value": 0},
      {"code": "police_next_status", "value": 0},
      {"code": "administrative_services_next_status", "value": 0}
    ]',
    in_actor_id,
    v_reason);
  -- Смена типа экономики
  perform data.change_object_and_notify(
    in_aster_id,
    format(
      '[
        {"code": "person_state", "value": "un"},
        {"code": "person_un_rating", "value": %s},
        {"code": "system_person_economy_type", "value": "un"},
        {"code": "person_economy_type", "value": "un", "value_object_code": "master"},
        {"code": "system_money"},
        {"code": "money", "value_object_id": %s},
        {"code": "money", "value_object_code": "master"},
        {"code": "system_person_deposit_money"},
        {"code": "person_deposit_money", "value_object_id": %s},
        {"code": "person_deposit_money", "value_object_code": "master"}
      ]',
      v_base_rating,
      in_aster_id,
      in_aster_id)::jsonb);

  -- Отмена всех контрактов
  for v_contract_id in
    select data.get_object_id(value)
    from unnest(v_contracts) a(value)
  loop
    perform data.change_object_and_notify(
      v_contract_id,
      jsonb '{"contract_status": "not_active"}');
    perform pallas_project.notify_contract(v_contract_id, 'Контракт отменён в связи со сменой гражданства');
  end loop;

  -- Уведомление
  v_un_hints_id :=
    data.create_object(
      null,
      format(
        '[
          {"code": "type", "value": "un_citizen_hints"},
          {"code": "is_visible", "value": true, "value_object_id": %s},
          {"code": "title", "value": "Советы для получивших гражданство"},
          {"code": "description", "value": "Уважаемый гражданин!\n\nТеперь вы являетесь полноценным представителем ООН, а значит, можете работать на благо всего общества.\nПозвольте дать вам несколько советов:\n1. Ваши статусы на следующий цикл выставлены в значение по умолчанию, также вам начислено количество коинов, соответствующее вашему рейтингу гражданина. Не забудьте их [потратить](babcom:%s_next_statuses)!\n2. Гражданин не просто может, но *должен* работать. Найдите работу, чтобы ваш рейтинг не падал, а вы не потеряли с таким трудом приобретённое гражданство.\n3. Работайте лучше. Чем лучше вы работаете, тем быстрее растёт ваш рейтинг и тем более ответственные должности вы можете занимать.\n\nНадеемся на долгое сотрудничетво, ваши коллеги из ООН!"},
          {"code": "template", "value": {"title": "title", "groups": [{"code": "group", "attributes": ["description"]}]}}
        ]',
        in_aster_id,
        v_aster_code)::jsonb);
  perform pp_utils.add_notification(in_aster_id, 'Вам доступна памятка гражданина ООН, не забудьте ознакомиться!', v_un_hints_id, true);
end;
$$
language plpgsql;
