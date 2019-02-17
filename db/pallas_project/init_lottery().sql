-- drop function pallas_project.init_lottery();

create or replace function pallas_project.init_lottery()
returns void
volatile
as
$$
declare
  v_object_id integer;
  v_lottery_owner_code text;
begin
  insert into data.params(code, value) values
  ('lottery_ticket_price', jsonb '10');

  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('lottery_ticket_count', 'Количество билетов', 'Количество купленных лотерейных билетов', 'normal', 'full', null, true),
  ('lottery_status', 'Статус', null, 'normal', 'full', 'pallas_project.vd_lottery_status', false),
  ('system_lottery_owner', null, 'Человек, завершающий лотерею', 'system', null, null, false);

  insert into data.actions(code, function) values
  ('buy_lottery_ticket', 'pallas_project.act_buy_lottery_ticket'),
  ('finish_lottery', 'pallas_project.act_finish_lottery'),
  ('cancel_lottery', 'pallas_project.act_cancel_lottery');

  select data.get_object_code(object_id)
  into v_lottery_owner_code
  from data.attribute_values
  where
    attribute_id = data.get_attribute_id('title') and
    value = jsonb '"Джерри Адамс"' and
    value_object_id is null;

  v_object_id :=
    data.create_object(
      'lottery',
      format(
        '[
          {"code": "is_visible", "value": true},
          {"code": "title", "value": "Лотерея гражданства ООН"},
          {"code": "type", "value": "lottery"},
          {"code": "lottery_status", "value": "active"},
          {"code": "system_lottery_owner", "value": "%s"},
          {"code": "actions_function", "value": "pallas_project.actgenerator_lottery"},
          {"code": "description", "value": "Все неграждане, присутствующие на астероиде Паллада на момент старта лотереи, официально зарегистрированные и имеющие комм на момент начала лотереи, получают ОДИН билет ЛОТЕРЕИ ГРАЖДАНСТВА совершенно бесплатно.\n\nКаждый негражданин может ДОПОЛНИТЕЛЬНО приобрести ЛЮБОЕ количество билетов лотереи. Стоимость дополнительного билета — UN$10.\n\nПерепродажа и передача билетов ЛОТЕРЕИ ГРАЖДАНСТВА запрещены.\n\nОтказаться от участия в ЛОТЕРЕЕ ГРАЖДАНСТВА нельзя.\n\nОДИН победитель определяется методом случайного выбора между ВСЕМИ (гарантированными и дополнительно приобретенными) билетами ЛОТЕРЕИ ГРАЖДАНСТВА.\n\nЛОТЕРЕЯ ГРАЖДАНСТВА проводится Амандой Ганди, заместителем отдела внутренней ревизии Управления по вопросам космического пространства ООН. Контролёрами ЛОТЕРЕИ ГРАЖДАНСТВА со стороны астероида Паллада назначаются Александр Корсак, главный экономист, и Кара Трейс, военный наблюдатель.\n\nПОБЕДИТЕЛЬ получит официальное уведомление на свой комм сразу же после завершения лотереи, также он будет объявлен в местных и земных новостях.\n\nГражданство может быть отозвано, если выяснится, что награжденный скрывался от правосудия или совершил уголовно наказуемое деяние до победы в лотерее.\n\nФинальный этап состоится на празднике, посвященном юбилею станции, после торжественной речи Аманды Ганди."},
          {
            "code": "template",
            "value": {
              "title": "title",
              "groups": [
                {"code": "tickets", "attributes": ["lottery_status", "lottery_ticket_count"], "actions": ["buy_lottery_ticket", "finish_lottery", "cancel_lottery"]},
                {"name": "Правила проведения ЛОТЕРЕИ ГРАЖДАНСТВА", "code": "rules", "attributes": ["description"]}
              ]
            }
          }
        ]',
        v_lottery_owner_code)::jsonb);

  -- Всем астерам добавляем по одному билету
  declare
    v_person_id integer;
  begin
    for v_person_id in
    (
      select oo.object_id
      from data.object_objects oo
      where
        oo.parent_object_id = data.get_object_id('player') and
        oo.parent_object_id != oo.object_id
    )
    loop
      if json.get_string(data.get_attribute_value(v_person_id, 'system_person_economy_type')) = 'asters' then
        perform data.set_attribute_value(v_object_id, data.get_attribute_id('lottery_ticket_count'), jsonb '1', v_person_id);
      end if;
    end loop;
  end;
end;
$$
language plpgsql;
