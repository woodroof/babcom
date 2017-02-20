-- Расширения
insert into data.extensions(code) values
('meta'),
('mail'),
('history'),
('notifications');

-- Вспомогательные функции
CREATE OR REPLACE FUNCTION utils.system_time(in_days_shift integer DEFAULT NULL::integer)
  RETURNS text AS
$BODY$
declare
  v_years_shift integer := data.get_integer_param('years_shift');
  v_time timestamp with time zone;
begin
  if in_days_shift is null then
    v_time := now() + (v_years_shift || 'y')::interval;
  else
    v_time := now() + (v_years_shift || 'y')::interval + (in_days_shift || 'd')::interval;
  end if;

  return to_char(v_time, 'yyyy.mm.dd hh24:mi:ss.us');
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION utils.current_time(in_days_shift integer DEFAULT NULL::integer)
  RETURNS text AS
$BODY$
declare
  v_years_shift integer := data.get_integer_param('years_shift');
  v_time timestamp with time zone;
begin
  if in_days_shift is null then
    v_time := now() + (v_years_shift || 'y')::interval;
  else
    v_time := now() + (v_years_shift || 'y')::interval + (in_days_shift || 'd')::interval;
  end if;

  return to_char(v_time, 'dd.mm.yyyy hh24:mi');
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

-- Параметры
insert into data.params(code, value, description) values
('years_shift', jsonb '241', 'Смещение года'),
('template', jsonb '
{
  "groups": [
    {
      "attributes": ["balance"]
    },
    {
      "attributes": ["transaction_time", "transaction_sum", "balance_rest", "transaction_from", "transaction_to", "transaction_description"]
    },
    {
      "actions": ["generate_money", "state_money_transfer", "transfer", "send_mail", "send_mail_from_future"]
    },
    {
      "attributes": ["person_race", "person_state", "person_psi_scale", "person_job_position"]
    },
    {
      "attributes": ["person_biography"]
    },
    {
      "attributes": ["mail_type", "mail_send_time", "mail_title", "mail_author", "mail_receivers"],
      "actions": ["reply", "reply_all", "delete_mail"]
    },
    {
      "attributes": ["mail_body"]
    },
    {
      "attributes": ["news_time", "news_media", "news_title"]
    },
    {
      "attributes": ["state_tax"],
      "actions": ["change_state_tax"]
    },
    {
      "attributes": ["corporation_state", "corporation_members", "corporation_capitalization", "corporation_sectors", "dividend_vote"],
      "actions": ["set_dividend_vote"]
    },
    {
      "actions": ["create_deal"]
    },
    {
      "attributes": ["corporation_deals", "corporation_draft_deals", "corporation_canceled_deals"]
    },
    {
      "attributes": ["document_title", "document_time", "document_author"]
    },
    {
      "attributes": ["med_document_patient"]
    },
    {
      "attributes": ["deal_time", "deal_cancel_time", "deal_status", "deal_sector", "asset_name", "asset_cost", "asset_amortization", "deal_income"],
      "actions": ["edit_deal", "delete_deal"]
    },
    {
      "attributes": ["deal_participant1"],
      "actions": ["edit_deal_member1", "delete_deal_member1"]
    },
    {
      "attributes": ["deal_participant2"],
      "actions": ["edit_deal_member2", "delete_deal_member2"]
    },
    {
      "attributes": ["deal_participant3"],
      "actions": ["edit_deal_member3", "delete_deal_member3"]
    },
    {
      "attributes": ["deal_participant4"],
      "actions": ["edit_deal_member4", "delete_deal_member4"]
    },
    {
      "attributes": ["deal_participant5"],
      "actions": ["edit_deal_member5", "delete_deal_member5"]
    },
    {
      "attributes": ["deal_participant6"],
      "actions": ["edit_deal_member6", "delete_deal_member6"]
    },
    {
      "attributes": ["deal_participant7"],
      "actions": ["edit_deal_member7", "delete_deal_member7"]
    },
    {
      "attributes": ["deal_participant8"],
      "actions": ["edit_deal_member8", "delete_deal_member8"]
    },
    {
      "attributes": ["deal_participant9"],
      "actions": ["edit_deal_member9", "delete_deal_member9"]
    },
    {
      "attributes": ["deal_participant10"],
      "actions": ["edit_deal_member10", "delete_deal_member10"]
    },
    {
      "actions": ["add_deal_member"]
    },
    {
      "attributes": ["description", "content"]
    },
    {
      "actions": ["login"]
    },
    {
      "attributes": ["sector_volume", "sector_volume_changes"]
    }
  ]
}
', 'Шаблон объекта');

-- Группы
insert into data.objects(code) values
('persons'),
('masters'),
('telepaths'),
('security'),
('politicians'),
('medics'),
('med_documents'),
('technicians'),
('pilots'),
('officers'),
('hackers'),
('scientists'),
('corporations'),
('ships'),
('news_hub'),
('states'),
('normal_deals'),
('draft_deals'),
('canceled_deals');

insert into data.objects(code)
select 'media' || o.value from generate_series(1, 3) o(value);

insert into data.objects(code)
select 'race' || o.value from generate_series(1, 20) o(value);

insert into data.objects(code)
select 'state' || o.value from generate_series(1, 10) o(value);

-- Персонажи
insert into data.objects(code) values
('anonymous');

insert into data.objects(code)
select 'person' || o.* from generate_series(1, 60) o;

-- Объекты
insert into data.objects(code) values
('mail_contacts'),
('transaction_destinations'),
('personal_document_storage'),
('library'),
('mailbox'),
('inbox'),
('outbox'),
('med_library'),
('transactions'),
('station'),
('station_medlab'),
('station_lab'),
('station_radar'),
('station_power_computer'),
('station_hacker_computer'),
('ship'),
('ship_radar'),
('ship_power_computer'),
('ship_hacker_computer'),
('assembly'),
('market'),
('meta_entities');

insert into data.objects(code)
select 'global_notification' || o.* from generate_series(1, 3) o;

insert into data.objects(code)
select 'personal_notification' || o.* from generate_series(1, 60) o;

insert into data.objects(code)
select 'station_weapon' || o.* from generate_series(1, 4) o;

insert into data.objects(code)
select 'station_reactor' || o.* from generate_series(1, 4) o;

insert into data.objects(code)
select 'ship_weapon' || o.* from generate_series(1, 2) o;

insert into data.objects(code)
select 'ship_reactor' || o.* from generate_series(1, 2) o;

insert into data.objects(code)
select 'corporation' || o.* from generate_series(1, 11) o;

insert into data.objects(code)
select 'news' || o1.* || o2.* from generate_series(1, 3) o1(value)
join generate_series(1, 100) o2(value) on 1=1;

insert into data.objects(code)
select 'library_category' || o.* from generate_series(1, 9) o;

insert into data.objects(code)
select 'library_document' || o1.* || o2.* from generate_series(1, 9) o1(value)
join generate_series(1, 20) o2(value) on 1=1;

insert into data.objects(code)
select 'personal_document' || o1.* from generate_series(1, 100) o1(value);

insert into data.objects(code)
select 'med_document' || o1.* from generate_series(1, 15) o1(value);

insert into data.objects(code)
select 'sector' || o1.* from generate_series(1, 4) o1(value);

insert into data.objects(code)
select 'deal' || o1.* from generate_series(1, 30) o1(value);

-- Функции для получения значений атрибутов
CREATE OR REPLACE FUNCTION attribute_value_description_functions.person_race(
    in_user_object_id integer,
    in_attribute_id integer,
    in_value jsonb)
  RETURNS text AS
$BODY$
declare
  v_text_value text := json.get_string(in_value);
begin
  for i in 1..20 loop
    if v_text_value = ('race' || i) then
      return 'Race ' || i || ' value description';
    end if;
  end loop;

  return null;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION attribute_value_description_functions.person_state(
    in_user_object_id integer,
    in_attribute_id integer,
    in_value jsonb)
  RETURNS text AS
$BODY$
declare
  v_text_value text := json.get_string(in_value);
begin
  for i in 1..10 loop
    if v_text_value = ('state' || i) then
      return 'State ' || i || ' value description';
    end if;
  end loop;

  return null;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION attribute_value_description_functions.person_psi_scale(
    in_user_object_id integer,
    in_attribute_id integer,
    in_value jsonb)
  RETURNS text AS
$BODY$
declare
  v_int_value integer := json.get_integer(in_value);
begin
  return 'P' || v_int_value;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION attribute_value_description_functions.mail_type(
    in_user_object_id integer,
    in_attribute_id integer,
    in_value jsonb)
  RETURNS text AS
$BODY$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'inbox' then
    return 'Входящее';
  when v_text_value = 'outbox' then
    return 'Исходящее';
  end case;

  return null;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION attribute_value_description_functions.deal_status(
    in_user_object_id integer,
    in_attribute_id integer,
    in_value jsonb)
  RETURNS text AS
$BODY$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'draft' then
    return 'Подготавливается';
  when v_text_value = 'normal' then
    return 'Утверждена';
  when v_text_value = 'canceled' then
    return 'Расторгнута';
  when v_text_value = 'deleted' then
    return 'Удалена';
  end case;

  return null;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

-- Атрибуты
insert into data.attributes(code, name, type, value_description_function) values
('persons', 'Список доступных персонажей', 'INVISIBLE', null),
('mail_contacts', 'Список доступных контактов', 'INVISIBLE', null),
('transaction_destinations', 'Список доступных назначений переводов', 'INVISIBLE', null),
('type', 'Тип', 'HIDDEN', null),
('name', 'Имя', 'NORMAL', null),
('description', 'Описание', 'NORMAL', null),
('content', 'Содержимое', 'NORMAL', null),
('system_value', 'Содержимое', 'SYSTEM', null),
('meta_entities', 'Мета-объекты', 'INVISIBLE', null),
('notifications', 'Уведомления', 'INVISIBLE', null),
('notification_description', 'Описание уведомления', 'NORMAL', null),
('notification_object_code', 'Объект, привязанный к уведомлению', 'HIDDEN', null),
('notification_time', 'Время отправки уведомления', 'NORMAL', null),
('notification_status', 'Статус уведомления', 'INVISIBLE', null),
('system_meta', 'Маркер мета-объекта', 'SYSTEM', null),
('system_mail_contact', 'Маркер объекта, которому можно отправлять письма', 'SYSTEM', null),
('person_race', 'Раса', 'NORMAL', 'person_race'),
('person_state', 'Государство', 'NORMAL', 'person_state'),
('person_job_position', 'Должность', 'NORMAL', null),
('person_biography', 'Биография', 'NORMAL', null),
('system_psi_scale', 'Рейтинг телепата', 'SYSTEM', null),
('person_psi_scale', 'Рейтинг телепата', 'NORMAL', 'person_psi_scale'),
('system_mail_folder_type', 'Тип папки писем', 'SYSTEM', null),
('mail_title', 'Заголовок', 'NORMAL', null),
('system_mail_send_time', 'Реальное время отправки письма', 'SYSTEM', null),
('mail_send_time', 'Время отправки письма', 'NORMAL', null),
('mail_author', 'Автор', 'NORMAL', 'code'),
('mail_receivers', 'Получатели', 'NORMAL', 'codes'),
('mail_body', 'Тело', 'NORMAL', null),
('mail_type', 'Тип письма', 'NORMAL', 'mail_type'),
('inbox', 'Входящие письма', 'INVISIBLE', null),
('outbox', 'Исходящие письма', 'INVISIBLE', null),
('transaction_from', 'Отправитель', 'NORMAL', 'code'),
('transaction_to', 'Получатель', 'NORMAL', 'code'),
('transaction_time', 'Время перевода', 'NORMAL', null),
('transaction_description', 'Сообщение', 'NORMAL', null),
('transaction_sum', 'Сумма', 'NORMAL', null),
('balance_rest', 'Остаток после операции', 'NORMAL', null),
('corporations', 'Все корпорации', 'INVISIBLE', null),
('corporation_state', 'Государство корпорации', 'NORMAL', 'code'),
('system_corporation_members', 'Члены корпорации', 'SYSTEM', null),
('corporation_members', 'Члены корпорации', 'NORMAL', null),
('system_corporation_capitalization', 'Капитализация корпорации', 'SYSTEM', null),
('corporation_capitalization', 'Капитализация корпорации', 'NORMAL', null),
('corporation_sectors', 'Рынки корпорации', 'NORMAL', 'codes'),
('system_corporation_deals', 'Активные сделки корпорации', 'SYSTEM', null),
('corporation_deals', 'Активные сделки корпорации', 'NORMAL', null),
('system_corporation_draft_deals', 'Подготавливаемые сделки корпорации', 'SYSTEM', null),
('corporation_draft_deals', 'Подготавливаемые сделки корпорации', 'NORMAL', null),
('system_corporation_canceled_deals', 'Расторгнутые сделки корпорации', 'SYSTEM', null),
('corporation_canceled_deals', 'Расторгнутые сделки корпорации', 'NORMAL', null),
('dividend_vote', 'Согласие на выплату дивидендов', 'NORMAL', null),
('system_deal_time', 'Дата изменения сделки', 'SYSTEM', null),
('deal_time', 'Дата утверждения сделки', 'NORMAL', null),
('deal_cancel_time', 'Дата расторжения сделки', 'NORMAL', null),
('deal_status', 'Статус сделки', 'NORMAL', 'deal_status'),
('deal_author', 'Автор сделки', 'SYSTEM', null),
('deal_sector', 'Рынок сделки', 'NORMAL', 'code'),
('asset_name', 'Имя актива', 'NORMAL', null),
('asset_cost', 'Стоимость актива', 'NORMAL', null),
('document_title', 'Заголовок документа', 'NORMAL', null),
('system_document_time', 'Реальное время создания документа', 'SYSTEM', null),
('document_time', 'Время создания', 'NORMAL', null),
('document_author', 'Автор', 'NORMAL', 'code'),
('med_document_patient', 'Пациент', 'NORMAL', 'code'),
('market_volume', 'Объём рынка', 'NORMAL', null),
('sectors', 'Отрасли', 'INVISIBLE', null),
('asset_amortization', 'Расходность актива', 'NORMAL', null),
('deal_income', 'Доходность сделки', 'NORMAL', null),
('system_deal_participant1', 'Участник сделки 1', 'SYSTEM', null),
('deal_participant1', 'Участник сделки 1', 'NORMAL', null),
('system_deal_participant2', 'Участник сделки 2', 'SYSTEM', null),
('deal_participant2', 'Участник сделки 2', 'NORMAL', null),
('system_deal_participant3', 'Участник сделки 3', 'SYSTEM', null),
('deal_participant3', 'Участник сделки 3', 'NORMAL', null),
('system_deal_participant4', 'Участник сделки 4', 'SYSTEM', null),
('deal_participant4', 'Участник сделки 4', 'NORMAL', null),
('system_deal_participant5', 'Участник сделки 5', 'SYSTEM', null),
('deal_participant5', 'Участник сделки 5', 'NORMAL', null),
('system_deal_participant6', 'Участник сделки 6', 'SYSTEM', null),
('deal_participant6', 'Участник сделки 6', 'NORMAL', null),
('system_deal_participant7', 'Участник сделки 7', 'SYSTEM', null),
('deal_participant7', 'Участник сделки 7', 'NORMAL', null),
('system_deal_participant8', 'Участник сделки 8', 'SYSTEM', null),
('deal_participant8', 'Участник сделки 8', 'NORMAL', null),
('system_deal_participant9', 'Участник сделки 9', 'SYSTEM', null),
('deal_participant9', 'Участник сделки 9', 'NORMAL', null),
('system_deal_participant10', 'Участник сделки 10', 'SYSTEM', null),
('deal_participant10', 'Участник сделки 10', 'NORMAL', null),
('transactions', 'Транзакции', 'SYSTEM', null),
('sector_volume', 'Объём отрасли', 'NORMAL',null),
('sector_volume_changes', 'Изменение объёма отрасли', 'NORMAL',null),
('state_tax', 'Ставка налога в стране, %', 'NORMAL', null),
('system_balance', 'Остаток на счету', 'SYSTEM', null),
('balance', 'Остаток на счету', 'NORMAL', null),
('system_master', 'Маркер мастерского персонажа', 'SYSTEM', null),
('system_security', 'Маркер персонажа, имеющего доступ к системе безопасности', 'SYSTEM', null),
('system_politician', 'Маркер персонажа-политика', 'SYSTEM', null),
('system_medic', 'Маркер персонажа-медика', 'SYSTEM', null),
('system_med_documents', 'Маркер персонажа, имеющего доступ к медицинским документам', 'SYSTEM', null),
('system_technician', 'Маркер персонажа-техника', 'SYSTEM', null),
('system_pilot', 'Маркер персонажа-пилота', 'SYSTEM', null),
('system_officer', 'Маркер персонажа-офицера', 'SYSTEM', null),
('system_hacker', 'Маркер персонажа-хакера', 'SYSTEM', null),
('system_scientist', 'Маркер персонажа-учёного', 'SYSTEM', null),
('system_library_category', 'Категория документа', 'SYSTEM', null),
('news_title', 'Заголовок новости', 'NORMAL', null),
('news_media', 'Источник новости', 'NORMAL', 'code'),
('system_news_time', 'Реальное время публикации новости', 'SYSTEM', null),
('news_time', 'Время публикации новости', 'NORMAL', null);

CREATE OR REPLACE FUNCTION attribute_value_change_functions.json_member_to_object(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_user_object_id integer := json.get_opt_integer(in_params, null, 'user_object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_attribute_value jsonb;
begin
  v_attribute_value := data.get_attribute_value(v_object_id, v_object_id, v_attribute_id);
  
  perform data.remove_object_from_object(oo.object_id, v_object_id)
    from data.object_objects oo
    where oo.parent_object_id = v_object_id and
          oo.parent_object_id != oo.object_id and
          oo.object_id not in (select data.get_object_id(member) from jsonb_to_recordset(v_attribute_value) as (member text));

  perform data.add_object_to_object(data.get_object_id(member), v_object_id)
    from jsonb_to_recordset(v_attribute_value) as (member text);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- Функции для создания связей
insert into data.attribute_value_change_functions(attribute_id, function, params) values
(data.get_attribute_id('type'), 'string_value_to_object', jsonb '{"params": {"person": "persons", "corporation": "corporations", "ship": "ships", "news": "news_hub", "library_category": "library", "med_document": "med_library", "sector": "market", "state": "states", "mail_folder": "mailbox"}}'),
(data.get_attribute_id('type'), 'string_value_to_attribute', jsonb '{"params": {"person": {"object_code": "transaction_destinations", "attribute_code": "transaction_destinations"}, "state": {"object_code": "transaction_destinations", "attribute_code": "transaction_destinations"}, "corporation": {"object_code": "transaction_destinations", "attribute_code": "transaction_destinations"}}}'),
(data.get_attribute_id('type'), 'string_value_to_attribute', jsonb '{"params": {"person": {"object_code": "persons", "attribute_code": "persons"}, "sector": {"object_code": "market", "attribute_code": "sectors"}, "corporation": {"object_code": "corporations", "attribute_code": "corporations"}}}'),
(data.get_attribute_id('system_master'), 'boolean_value_to_object', jsonb '{"object_code": "masters"}'),
(data.get_attribute_id('system_psi_scale'), 'any_value_to_object', jsonb '{"object_code": "telepaths"}'),
(data.get_attribute_id('system_security'), 'boolean_value_to_object', jsonb '{"object_code": "security"}'),
(data.get_attribute_id('system_politician'), 'boolean_value_to_object', jsonb '{"object_code": "politicians"}'),
(data.get_attribute_id('system_medic'), 'boolean_value_to_object', jsonb '{"object_code": "medics"}'),
(data.get_attribute_id('system_med_documents'), 'boolean_value_to_object', jsonb '{"object_code": "med_documents"}'),
(data.get_attribute_id('system_technician'), 'boolean_value_to_object', jsonb '{"object_code": "technicians"}'),
(data.get_attribute_id('system_pilot'), 'boolean_value_to_object', jsonb '{"object_code": "pilots"}'),
(data.get_attribute_id('system_officer'), 'boolean_value_to_object', jsonb '{"object_code": "officers"}'),
(data.get_attribute_id('system_hacker'), 'boolean_value_to_object', jsonb '{"object_code": "hackers"}'),
(data.get_attribute_id('system_scientist'), 'boolean_value_to_object', jsonb '{"object_code": "scientists"}'),
(data.get_attribute_id('system_mail_contact'), 'boolean_value_to_attribute', jsonb '{"object_code": "mail_contacts", "attribute_code": "mail_contacts"}'),
(data.get_attribute_id('system_meta'), 'boolean_value_to_value_attribute', jsonb '{"object_code": "meta_entities", "attribute_code": "meta_entities"}'),
(data.get_attribute_id('system_corporation_members'), 'json_member_to_object', null),
(data.get_attribute_id('deal_status'), 'string_value_to_object', jsonb '{"params": {"normal": "normal_deals", "draft": "draft_deals", "canceled": "canceled_deals"}}');

insert into data.attribute_value_change_functions(attribute_id, function, params)
select data.get_attribute_id('system_library_category'), 'string_value_to_object', ('{"params": {' || string_agg(s.value, ',') || '}}')::jsonb
from (select '"library_category' || o.value || '": "library_category' || o.value || '"' as value from generate_series(1, 9) o(value)) s;

insert into data.attribute_value_change_functions(attribute_id, function, params)
select data.get_attribute_id('person_race'), 'string_value_to_object', ('{"params": {' || string_agg(s.value, ',') || '}}')::jsonb
from (select '"race' || o.value || '": "race' || o.value || '"' as value from generate_series(1, 20) o(value)) s;

insert into data.attribute_value_change_functions(attribute_id, function, params)
select data.get_attribute_id('person_state'), 'string_value_to_object', ('{"params": {' || string_agg(s.value, ',') || '}}')::jsonb
from (select '"state' || o.value || '": "state' || o.value || '"' as value from generate_series(1, 10) o(value)) s;

select data.add_object_to_object(data.get_object_id('personal_document' || o.value), data.get_object_id('person' || ((o.value - 1) % 50 + 1))) from generate_series(1, 100) o(value);

select data.add_object_to_object(data.get_object_id('news' || o1.value || o2.value), data.get_object_id('media' || o1.value))
from generate_series(1, 3) o1(value)
join generate_series(1, 100) o2(value) on 1=1;

  -- TODO: Заполнить попадание в ship и station

-- Функции для вычисления атрибутов
CREATE OR REPLACE FUNCTION attribute_value_fill_functions.merge_metaobjects(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_source_object_id integer := data.get_object_id(json.get_string(in_params, 'object_code'));
  v_source_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));

  v_metaobjects record;

  v_attribute_name_id integer := data.get_attribute_id('name');
  v_groups jsonb :=
    json_build_array(
      json_build_object(
        'objects',
        json_build_array(
          json_build_object(
            'code',
            data.get_object_code(v_user_object_id),
            'name',
            data.get_attribute_value(v_user_object_id, v_user_object_id, v_attribute_name_id)))));
  v_codes text[];
  v_actions jsonb;
  v_action_array jsonb;
  v_action jsonb;
  v_objects jsonb;
begin
  for v_metaobjects in
    select json.get_string_array(av.value) codes
    from data.attribute_values av
    left join data.object_objects oo on
      av.value_object_id = oo.parent_object_id and
      oo.object_id = v_user_object_id
    where
      av.object_id = v_source_object_id and
      av.attribute_id = v_source_attribute_id and
      (
        av.value_object_id is null or
        oo.id is not null
      )
  loop
    v_codes := v_codes || v_metaobjects.codes;
  end loop;

  v_actions := data.get_object_actions(v_user_object_id, null);

  if v_actions is not null then
    v_action_array := jsonb '[]';
    for v_action in
      select value
      from jsonb_each(v_actions)
    loop
      v_action_array := v_action_array || v_action;
    end loop;

    v_groups := v_groups || jsonb_build_array(jsonb_build_object('actions', v_action_array));
  end if;

  select jsonb_agg(value)
  into v_objects
  from (
    select jsonb_build_object('code', o.code, 'name', o.name) as value
    from (
      select o.code, json.get_opt_string(data.get_attribute_value(v_user_object_id, o.id, v_attribute_name_id)) as name
      from data.objects o
      where o.code = any(v_codes)
      order by name
    ) o
  ) o;

  if v_objects is not null then
    v_groups := v_groups || jsonb_build_array(jsonb_build_object('objects', v_objects));
  end if;

  perform data.set_attribute_value_if_changed(
    v_user_object_id,
    v_attribute_id,
    v_user_object_id,
    jsonb_build_object('groups', v_groups),
    v_user_object_id);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(
  data.get_attribute_id('meta_entities'),
  'fill_if_user_object',
  '{
    "function": "fill_if_object_attribute",
    "params": {
      "blocks": [
        {
          "conditions": [
            {"attribute_code": "type", "attribute_value": "person"},
            {"attribute_code": "type", "attribute_value": "anonymous"}
          ],
          "function": "merge_metaobjects",
          "params": {
            "object_code": "meta_entities",
            "attribute_code": "meta_entities"
          }
        }
      ]
    }
  }',
  'Заполнение списка метаобъектов игрока');

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_user_content(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_placeholder text := json.get_opt_string(in_params, null, 'placeholder');

  v_sort_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'sort_attribute_code'));
  v_sort_type text := json.get_string(in_params, 'sort_type');

  v_output jsonb := json.get_object_array(in_params, 'output');

  v_next_object_id integer;
  v_output_entry jsonb;

  v_content_entry text;
  v_type text;
  v_output_attribute_id integer;
  v_content text;
begin
  assert v_sort_type = 'asc' or v_sort_type = 'desc';

  for v_next_object_id in
    execute '
      select object_id
      from data.object_objects
      where
        parent_object_id = $1 and
        intermediate_object_ids is null and
        parent_object_id != object_id
      order by data.get_attribute_value($2, object_id, $3) ' || v_sort_type
    using v_object_id, v_user_object_id, v_sort_attribute_id
  loop
    v_content_entry := '';

    for v_output_entry in
      select value
      from jsonb_array_elements(v_output)
    loop
      v_type := json.get_string(v_output_entry, 'type');
      if v_type = 'attribute' then
        v_output_attribute_id := data.get_attribute_id(json.get_string(v_output_entry, 'data'));

        perform data.fill_attribute_values(v_user_object_id, array[v_next_object_id], array[v_output_attribute_id]);

        v_content_entry :=
          v_content_entry ||
          json.get_string(
            data.get_attribute_value(
              v_user_object_id,
              v_next_object_id,
              v_output_attribute_id));
      elsif v_type = 'code' then
        v_content_entry := v_content_entry || data.get_object_code(v_next_object_id);
      else
        assert v_type = 'string';
        v_content_entry := v_content_entry || json.get_string(v_output_entry, 'data');
      end if;
    end loop;

    if v_content is not null then
      v_content := v_content || E'<br>\n';
    end if;
    v_content := coalesce(v_content, '') || v_content_entry;
  end loop;

  if v_content is null and v_placeholder is not null then
    v_content := v_placeholder;
  end if;

  if v_content is null then
    perform data.delete_attribute_value_if_exists(
      v_object_id,
      v_attribute_id,
      v_user_object_id,
      v_user_object_id);
  else
    perform data.set_attribute_value_if_changed(
      v_object_id,
      v_attribute_id,
      v_user_object_id,
      to_jsonb(v_content),
      v_user_object_id);
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_content(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_placeholder text := json.get_opt_string(in_params, null, 'placeholder');

  v_sort_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'sort_attribute_code'));
  v_sort_type text := json.get_string(in_params, 'sort_type');

  v_output jsonb := json.get_object_array(in_params, 'output');

  v_next_object_id integer;
  v_output_entry jsonb;

  v_content_entry text;
  v_type text;
  v_content text;
begin
  assert v_sort_type = 'asc' or v_sort_type = 'desc';

  for v_next_object_id in
    execute '
      select oo.object_id
      from data.object_objects oo
      join data.attribute_values av on
        av.object_id = oo.object_id and
        av.attribute_id = $1 and
        av.value_object_id is null
      where
        oo.parent_object_id = $2 and
        oo.intermediate_object_ids is null and
        oo.parent_object_id != oo.object_id
      order by av.value ' || v_sort_type
    using v_sort_attribute_id, v_object_id
  loop
    v_content_entry := '';

    for v_output_entry in
      select value
      from jsonb_array_elements(v_output)
    loop
      v_type := json.get_string(v_output_entry, 'type');
      if v_type = 'attribute' then
        select v_content_entry || json.get_string(value)
        into v_content_entry
        from data.attribute_values
        where
          object_id = v_next_object_id and
          attribute_id = data.get_attribute_id(json.get_string(v_output_entry, 'data')) and
          value_object_id is null;
      elsif v_type = 'code' then
        v_content_entry := v_content_entry || data.get_object_code(v_next_object_id);
      else
        assert v_type = 'string';
        v_content_entry := v_content_entry || json.get_string(v_output_entry, 'data');
      end if;
    end loop;

    if v_content is not null then
      v_content := v_content || E'<br>\n';
    end if;
    v_content := coalesce(v_content, '') || v_content_entry;
  end loop;

  if v_content is null and v_placeholder is not null then
    v_content := v_placeholder;
  end if;

  if v_content is null then
    perform data.delete_attribute_value_if_exists(
      v_object_id,
      v_attribute_id,
      null,
      v_user_object_id);
  else
    perform data.set_attribute_value_if_changed(
      v_object_id,
      v_attribute_id,
      null,
      to_jsonb(v_content),
      v_user_object_id);
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_user_content_from_attribute(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_placeholder text := json.get_opt_string(in_params, null, 'placeholder');

  v_source_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'source_attribute_code'));
  v_sort_type text := json.get_string(in_params, 'sort_type');

  v_output jsonb := json.get_object_array(in_params, 'output');

  v_codes jsonb;

  v_next_object_id integer;
  v_output_entry jsonb;

  v_content_entry text;
  v_type text;
  v_output_attribute_id integer;
  v_content text;
begin
  assert v_sort_type = 'asc' or v_sort_type = 'desc';

  v_codes := data.get_attribute_value(v_user_object_id, v_object_id, v_source_attribute_id);
  perform json.get_opt_string_array(v_codes);

  if v_codes is not null then
    for v_next_object_id in
      execute '
        select data.get_object_id(json.get_string(o.value))
        from (
          select value, row_number() over() as num
          from jsonb_array_elements($1)
          order by num ' || v_sort_type || '
        ) o'
      using v_codes
    loop
      v_content_entry := '';

      for v_output_entry in
        select value
        from jsonb_array_elements(v_output)
      loop
        v_type := json.get_string(v_output_entry, 'type');
        if v_type = 'attribute' then
          v_output_attribute_id := data.get_attribute_id(json.get_string(v_output_entry, 'data'));

          perform data.fill_attribute_values(v_user_object_id, array[v_next_object_id], array[v_output_attribute_id]);

          v_content_entry :=
            v_content_entry ||
            json.get_string(
              data.get_attribute_value(
                v_user_object_id,
                v_next_object_id,
                v_output_attribute_id));
        elsif v_type = 'code' then
          v_content_entry := v_content_entry || data.get_object_code(v_next_object_id);
        else
          assert v_type = 'string';
          v_content_entry := v_content_entry || json.get_string(v_output_entry, 'data');
        end if;
      end loop;

      if v_content is not null then
        v_content := v_content || E'<br>\n';
      end if;
      v_content := coalesce(v_content, '') || v_content_entry;
    end loop;
  end if;

  if v_content is null and v_placeholder is not null then
    v_content := v_placeholder;
  end if;

  if v_content is null then
    perform data.delete_attribute_value_if_exists(
      v_object_id,
      v_attribute_id,
      v_user_object_id,
      v_user_object_id);
  else
    perform data.set_attribute_value_if_changed(
      v_object_id,
      v_attribute_id,
      v_user_object_id,
      to_jsonb(v_content),
      v_user_object_id);
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_user_content_from_user_value_attribute(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_placeholder text := json.get_opt_string(in_params, null, 'placeholder');

  v_source_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'source_attribute_code'));
  v_sort_type text := json.get_string(in_params, 'sort_type');

  v_output jsonb := json.get_object_array(in_params, 'output');

  v_codes jsonb;

  v_next_object_id integer;
  v_output_entry jsonb;

  v_content_entry text;
  v_type text;
  v_output_attribute_id integer;
  v_content text;
begin
  assert v_sort_type = 'asc' or v_sort_type = 'desc';

  v_codes := data.get_attribute_value(v_user_object_id, v_user_object_id, v_source_attribute_id);
  perform json.get_opt_string_array(v_codes);

  if v_codes is not null then
    for v_next_object_id in
      execute '
        select data.get_object_id(json.get_string(o.value))
        from (
          select value, row_number() over() as num
          from jsonb_array_elements($1)
          order by num ' || v_sort_type || '
        ) o'
      using v_codes
    loop
      v_content_entry := '';

      for v_output_entry in
        select value
        from jsonb_array_elements(v_output)
      loop
        v_type := json.get_string(v_output_entry, 'type');
        if v_type = 'attribute' then
          v_output_attribute_id := data.get_attribute_id(json.get_string(v_output_entry, 'data'));

          perform data.fill_attribute_values(v_user_object_id, array[v_next_object_id], array[v_output_attribute_id]);

          v_content_entry :=
            v_content_entry ||
            json.get_string(
              data.get_attribute_value(
                v_user_object_id,
                v_next_object_id,
                v_output_attribute_id));
        elsif v_type = 'code' then
          v_content_entry := v_content_entry || data.get_object_code(v_next_object_id);
        else
          assert v_type = 'string';
          v_content_entry := v_content_entry || json.get_string(v_output_entry, 'data');
        end if;
      end loop;

      if v_content is not null then
        v_content := v_content || E'<br>\n';
      end if;
      v_content := coalesce(v_content, '') || v_content_entry;
    end loop;
  end if;

  if v_content is null and v_placeholder is not null then
    v_content := v_placeholder;
  end if;

  if v_content is null then
    perform data.delete_attribute_value_if_exists(
      v_object_id,
      v_attribute_id,
      v_user_object_id,
      v_user_object_id);
  else
    perform data.set_attribute_value_if_changed(
      v_object_id,
      v_attribute_id,
      v_user_object_id,
      to_jsonb(v_content),
      v_user_object_id);
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_content_from_attribute(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_placeholder text := json.get_opt_string(in_params, null, 'placeholder');

  v_source_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'source_attribute_code'));
  v_sort_type text := json.get_string(in_params, 'sort_type');

  v_output jsonb := json.get_object_array(in_params, 'output');

  v_codes jsonb;

  v_next_object_id integer;
  v_output_entry jsonb;

  v_content_entry text;
  v_type text;
  v_content text;
begin
  assert v_sort_type = 'asc' or v_sort_type = 'desc';

  select value
  into v_codes
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_source_attribute_id and
    value_object_id is null;

  perform json.get_opt_string_array(v_codes);

  if v_codes is not null then
    for v_next_object_id in
      execute '
        select data.get_object_id(json.get_string(o.value))
        from (
          select value, row_number() over() as num
          from jsonb_array_elements($1)
          order by num ' || v_sort_type || '
        ) o'
      using v_codes
    loop
      v_content_entry := '';

      for v_output_entry in
        select value
        from jsonb_array_elements(v_output)
      loop
        v_type := json.get_string(v_output_entry, 'type');
        if v_type = 'attribute' then
          select v_content_entry || json.get_string(value)
          into v_content_entry
          from data.attribute_values
          where
            object_id = v_next_object_id and
            attribute_id = data.get_attribute_id(json.get_string(v_output_entry, 'data')) and
            value_object_id is null;
        elsif v_type = 'code' then
          v_content_entry := v_content_entry || data.get_object_code(v_next_object_id);
        else
          assert v_type = 'string';
          v_content_entry := v_content_entry || json.get_string(v_output_entry, 'data');
        end if;
      end loop;

      if v_content is not null then
        v_content := v_content || E'<br>\n';
      end if;
      v_content := coalesce(v_content, '') || v_content_entry;
    end loop;
  end if;

  if v_content is null and v_placeholder is not null then
    v_content := v_placeholder;
  end if;

  if v_content is null then
    perform data.delete_attribute_value_if_exists(
      v_object_id,
      v_attribute_id,
      null,
      v_user_object_id);
  else
    perform data.set_attribute_value_if_changed(
      v_object_id,
      v_attribute_id,
      null,
      to_jsonb(v_content),
      v_user_object_id);
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(
  data.get_attribute_id('content'),
  'fill_if_object_attribute', '
  {
    "blocks": [
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "news_hub"}, {"attribute_code": "type", "attribute_value": "media"}],
        "function": "fill_content",
        "params": {"placeholder": "Новостей нет", "sort_attribute_code": "system_news_time", "sort_type": "desc", "output": [{"type": "attribute", "data": "news_time"}, {"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "med_library"}],
        "function": "fill_user_content",
        "params": {"placeholder": "Отчётов нет", "sort_attribute_code": "system_document_time", "sort_type": "desc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "mailbox"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "name", "sort_type": "asc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "system_mail_folder_type", "attribute_value": "inbox"}],
        "function": "fill_user_content_from_user_value_attribute",
        "params": {"source_attribute_code": "inbox", "placeholder": "Писем нет", "sort_attribute_code": "system_mail_send_time", "sort_type": "desc", "output": [{"type": "attribute", "data": "mail_send_time"}, {"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "system_mail_folder_type", "attribute_value": "outbox"}],
        "function": "fill_user_content_from_user_value_attribute",
        "params": {"source_attribute_code": "outbox", "placeholder": "Писем нет", "sort_attribute_code": "system_mail_send_time", "sort_type": "desc", "output": [{"type": "attribute", "data": "mail_send_time"}, {"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "corporations"}, {"attribute_code": "type", "attribute_value": "market"}, {"attribute_code": "type", "attribute_value": "states"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "name", "sort_type": "asc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "transactions"}],
        "function": "fill_user_content_from_attribute",
        "params": {"placeholder": "Транзакций нет", "source_attribute_code": "system_value", "sort_type": "desc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "normal_deals"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_deal_time", "sort_type": "desc", "output": [{"type": "attribute", "data": "deal_time"}, {"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "canceled_deals"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_deal_time", "sort_type": "desc", "output": [{"type": "attribute", "data": "deal_cancel_time"}, {"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "draft_deals"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_deal_time", "sort_type": "desc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      }
    ]
  }', 'Получение списков (новости, транзакции, разные документы)');

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(
  data.get_attribute_id('corporation_deals'),
  'fill_if_object_attribute', '
  {
    "blocks": [
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "corporation"}],
        "function": "fill_content_from_attribute",
        "params": {"placeholder": "Подтверждённых сделок нет", "source_attribute_code": "system_corporation_deals", "sort_type": "desc", "output": [{"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      }
    ]
  }', 'Получение списка подтверждённых сделок');

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(
  data.get_attribute_id('corporation_draft_deals'),
  'fill_if_object_attribute', '
  {
    "blocks": [
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "corporation"}],
        "function": "fill_content_from_attribute",
        "params": {"placeholder": "Подготавливаемых сделок нет", "source_attribute_code": "system_corporation_draft_deals", "sort_type": "desc", "output": [{"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      }
    ]
  }', 'Получение списка подготавливаемых сделок');

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(
  data.get_attribute_id('corporation_canceled_deals'),
  'fill_if_object_attribute', '
  {
    "blocks": [
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "corporation"}],
        "function": "fill_content_from_attribute",
        "params": {"placeholder": "Расторгнутых сделок нет", "source_attribute_code": "system_corporation_canceled_deals", "sort_type": "desc", "output": [{"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      }
    ]
  }', 'Получение списка расторгнутых сделок');

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.value_codes_to_value_links_corporation_members(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_source_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));
  v_placeholder text := json.get_opt_string(in_params, null, 'placeholder');
  v_name_attribute_id integer := data.get_attribute_id('name');

  v_codes jsonb;
  v_ids integer[];
  v_value jsonb;
begin
  select value
  into v_codes
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_source_attribute_id and
    value_object_id is null
  for share;

  if v_codes is not null then
    select array_agg(id)
    into v_ids
    from data.objects
    where
      code in (
        select member
        from jsonb_to_recordset(v_codes) as c(member text, percent int)
      );
  end if;

  if v_codes is not null then
    perform data.fill_attribute_values(v_user_object_id, v_ids, array[v_name_attribute_id]);

    select to_jsonb(string_agg('<a href="babcom:' || o.code || '">' || json.get_string(data.get_attribute_value(v_user_object_id, o.id, v_name_attribute_id)) || '</a> ' || c.percent || '%', '<br>'))
    into v_value
    from jsonb_to_recordset(v_codes) as c(member text, percent int)
    join data.objects o on
      o.code = c.member;
  else
    if v_placeholder is not null then
      v_value := to_jsonb(v_placeholder);
    end if;
  end if;

  if v_value is null then
    perform data.delete_attribute_value_if_exists(v_object_id, v_attribute_id, v_user_object_id, v_user_object_id);
  else
    perform data.set_attribute_value_if_changed(v_object_id, v_attribute_id, v_user_object_id, v_value, v_user_object_id);
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.value_codes_to_value_links_deal_members(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_source_attribute_id integer := data.get_attribute_id(json.get_string(in_params, 'attribute_code'));
  v_placeholder text := json.get_opt_string(in_params, null, 'placeholder');
  v_name_attribute_id integer := data.get_attribute_id('name');

  v_codes jsonb;
  v_ids integer[];
  v_value jsonb;
begin
  select value
  into v_codes
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_source_attribute_id and
    value_object_id is null
  for share;

  if v_codes is not null then
    select array_agg(id)
    into v_ids
    from data.objects
    where
      code in (
        select member
        from jsonb_to_record(v_codes) as c(member text, percent_asset int, percent_income int, deal_cost int)
      );
  end if;

  if v_codes is not null then
    perform data.fill_attribute_values(v_user_object_id, v_ids, array[v_name_attribute_id]);

    select to_jsonb(string_agg('<a href="babcom:' || o.code || '">' || json.get_string(data.get_attribute_value(v_user_object_id, o.id, v_name_attribute_id)) || '</a>, владение активом: ' || c.percent_asset || '%, доход от сделки: ' || c.percent_income || '%, вложения в сделку: ' || c.deal_cost, '<br>'))
    into v_value
    from jsonb_to_record(v_codes) as c(member text, percent_asset int, percent_income int, deal_cost int)
    join data.objects o on
      o.code = c.member;
  else
    if v_placeholder is not null then
      v_value := to_jsonb(v_placeholder);
    end if;
  end if;

  if v_value is null then
    perform data.delete_attribute_value_if_exists(v_object_id, v_attribute_id, v_user_object_id, v_user_object_id);
  else
    perform data.set_attribute_value_if_changed(v_object_id, v_attribute_id, v_user_object_id, v_value, v_user_object_id);
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
  (
  data.get_attribute_id('corporation_members'),
  'fill_if_object_attribute', '
  {
    "blocks": [
    {
        "conditions": [{"attribute_code": "type", "attribute_value": "corporation"}],
        "function": "value_codes_to_value_links_corporation_members",
        "params": {"attribute_code": "system_corporation_members"}
      }]
  }', 'Получение списка владельцев корпорации');

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(
  data.get_attribute_id('deal_participant1'),
  'fill_if_object_attribute', '
  {
    "blocks": [
    {
        "conditions": [{"attribute_code": "type", "attribute_value": "deal"}],
        "function": "value_codes_to_value_links_deal_members",
        "params": {"attribute_code": "system_deal_participant1"}
      }]
  }', 'Получение участника сделки'),
(
  data.get_attribute_id('deal_participant2'),
  'fill_if_object_attribute', '
  {
    "blocks": [
    {
        "conditions": [{"attribute_code": "type", "attribute_value": "deal"}],
        "function": "value_codes_to_value_links_deal_members",
        "params": {"attribute_code": "system_deal_participant2"}
      }]
  }', 'Получение участника сделки'),
(
  data.get_attribute_id('deal_participant3'),
  'fill_if_object_attribute', '
  {
    "blocks": [
    {
        "conditions": [{"attribute_code": "type", "attribute_value": "deal"}],
        "function": "value_codes_to_value_links_deal_members",
        "params": {"attribute_code": "system_deal_participant3"}
      }]
  }', 'Получение участника сделки'),
(
  data.get_attribute_id('deal_participant4'),
  'fill_if_object_attribute', '
  {
    "blocks": [
    {
        "conditions": [{"attribute_code": "type", "attribute_value": "deal"}],
        "function": "value_codes_to_value_links_deal_members",
        "params": {"attribute_code": "system_deal_participant4"}
      }]
  }', 'Получение участника сделки'),
(
  data.get_attribute_id('deal_participant5'),
  'fill_if_object_attribute', '
  {
    "blocks": [
    {
        "conditions": [{"attribute_code": "type", "attribute_value": "deal"}],
        "function": "value_codes_to_value_links_deal_members",
        "params": {"attribute_code": "system_deal_participant5"}
      }]
  }', 'Получение участника сделки'),
(
  data.get_attribute_id('deal_participant6'),
  'fill_if_object_attribute', '
  {
    "blocks": [
    {
        "conditions": [{"attribute_code": "type", "attribute_value": "deal"}],
        "function": "value_codes_to_value_links_deal_members",
        "params": {"attribute_code": "system_deal_participant6"}
      }]
  }', 'Получение участника сделки'),
(
  data.get_attribute_id('deal_participant7'),
  'fill_if_object_attribute', '
  {
    "blocks": [
    {
        "conditions": [{"attribute_code": "type", "attribute_value": "deal"}],
        "function": "value_codes_to_value_links_deal_members",
        "params": {"attribute_code": "system_deal_participant7"}
      }]
  }', 'Получение участника сделки'),
(
  data.get_attribute_id('deal_participant8'),
  'fill_if_object_attribute', '
  {
    "blocks": [
    {
        "conditions": [{"attribute_code": "type", "attribute_value": "deal"}],
        "function": "value_codes_to_value_links_deal_members",
        "params": {"attribute_code": "system_deal_participant8"}
      }]
  }', 'Получение участника сделки'),
(
  data.get_attribute_id('deal_participant9'),
  'fill_if_object_attribute', '
  {
    "blocks": [
    {
        "conditions": [{"attribute_code": "type", "attribute_value": "deal"}],
        "function": "value_codes_to_value_links_deal_members",
        "params": {"attribute_code": "system_deal_participant9"}
      }]
  }', 'Получение участника сделки'),
(
  data.get_attribute_id('deal_participant10'),
  'fill_if_object_attribute', '
  {
    "blocks": [
    {
        "conditions": [{"attribute_code": "type", "attribute_value": "deal"}],
        "function": "value_codes_to_value_links_deal_members",
        "params": {"attribute_code": "system_deal_participant10"}
      }]
  }', 'Получение участника сделки');

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(data.get_attribute_id('transaction_destinations'), 'fill_if_object_attribute', '{"blocks": [{"conditions": [{"attribute_code": "type", "attribute_value": "transaction_destinations"}], "function": "filter_user_object_code"}]}', 'Получение списка возможных получателей переводов');

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_transaction_name(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_from text :=
    json.get_opt_string(
      data.get_attribute_value(
        v_user_object_id,
        v_object_id,
        data.get_attribute_id('transaction_from')));
  v_from_id integer := case when v_from is not null then data.get_object_id(v_from) else null end;
  v_to_id integer :=
    data.get_object_id(
      json.get_string(
        data.get_attribute_value(
          v_user_object_id,
          v_object_id,
          data.get_attribute_id('transaction_to'))));
begin
  perform data.set_attribute_value_if_changed(
    v_object_id,
    v_attribute_id,
    v_user_object_id,
    to_jsonb(
      json.get_string(data.get_attribute_value(v_user_object_id, v_object_id, data.get_attribute_id('transaction_time'))) || ' ' ||
      case when v_from_id = v_user_object_id then '−' else '+' end ||
      json.get_integer(data.get_attribute_value(v_user_object_id, v_object_id, data.get_attribute_id('transaction_sum'))) || ' (' ||
      json.get_integer(data.get_attribute_value(v_user_object_id, v_object_id, data.get_attribute_id('balance_rest'))) || ') ' ||
      case when v_to_id = v_user_object_id and v_from_id is not null then
        json.get_string(
          data.get_attribute_value(
            v_user_object_id,
            v_from_id,
            v_attribute_id))
      when v_to_id != v_user_object_id then
        json.get_string(
          data.get_attribute_value(
            v_user_object_id,
            v_to_id,
            v_attribute_id))
      end ||
      ': ' ||
      json.get_string(data.get_attribute_value(v_user_object_id, v_object_id, data.get_attribute_id('transaction_description')))));
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(data.get_attribute_id('name'), 'fill_if_object_attribute', '{"blocks": [{"conditions": [{"attribute_code": "type", "attribute_value": "transaction"}], "function": "fill_transaction_name"}]}', 'Получение имени транзакции');

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(
  data.get_attribute_id('balance'),
  'fill_if_user_object_attribute',
  '{
    "blocks": [
      {
        "conditions": [{"attribute_code": "system_master", "attribute_value": true}],
        "function": "fill_value_object_attribute_from_attribute",
        "params": {"value_object_code": "masters", "attribute_code": "system_balance"}
      },
      {
        "function": "fill_object_attribute_from_attribute",
        "params": {"attribute_code": "system_balance"}
      }
    ]
  }', 'Получение состояния счёта');

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(
  data.get_attribute_id('person_psi_scale'),
  'fill_if_user_object_attribute',
  '{
    "blocks": [
      {
        "conditions": [{"attribute_code": "system_master", "attribute_value": true}],
        "function": "fill_value_object_attribute_from_attribute",
        "params": {"value_object_code": "masters", "attribute_code": "system_psi_scale"}
      },
      {
        "function": "fill_object_attribute_from_attribute",
        "params": {"value_object_code": "masters", "attribute_code": "system_psi_scale"}
      }
    ]
  }', 'Получение рейтинга телепата');

  -- TODO и другие:
  -- personal_document_storage: system_value[player] -> content[player]
  -- library: object_objects[intermediate is null] -> content
  -- library_category{1,9}: object_objects[intermediate is null] -> content

-- Заполнение атрибутов
select data.set_attribute_value(data.get_object_id('mail_contacts'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('mail_contacts'), data.get_attribute_id('type'), null, jsonb '"mail_contacts"');
select data.set_attribute_value(data.get_object_id('mail_contacts'), data.get_attribute_id('name'), null, jsonb '"Доступные контакты"');

select data.set_attribute_value(data.get_object_id('transaction_destinations'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('transaction_destinations'), data.get_attribute_id('type'), null, jsonb '"transaction_destinations"');
select data.set_attribute_value(data.get_object_id('transaction_destinations'), data.get_attribute_id('name'), null, jsonb '"Возможные получатели переводов"');

select data.set_attribute_value(data.get_object_id('persons'), data.get_attribute_id('system_priority'), null, jsonb '10');
select data.set_attribute_value(data.get_object_id('persons'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('persons'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('persons'), data.get_attribute_id('name'), null, jsonb '"Все"');
select data.set_attribute_value(data.get_object_id('persons'), data.get_attribute_id('system_mail_contact'), null, jsonb 'true');

select data.set_attribute_value(data.get_object_id('masters'), data.get_attribute_id('system_priority'), null, jsonb '100');
select data.set_attribute_value(data.get_object_id('masters'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('masters'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('masters'), data.get_attribute_id('name'), null, jsonb '"Справочное бюро"');
select data.set_attribute_value(data.get_object_id('masters'), data.get_attribute_id('system_mail_contact'), null, jsonb 'true');

select data.set_attribute_value(data.get_object_id('telepaths'), data.get_attribute_id('system_priority'), null, jsonb '90');
select data.set_attribute_value(data.get_object_id('telepaths'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('telepaths'), data.get_attribute_id('name'), null, jsonb '"Телепаты"');

select data.set_attribute_value(data.get_object_id('security'), data.get_attribute_id('system_priority'), null, jsonb '70');
select data.set_attribute_value(data.get_object_id('security'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('security'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('security'), data.get_attribute_id('name'), null, jsonb '"Служба безопасности"');
select data.set_attribute_value(data.get_object_id('security'), data.get_attribute_id('system_mail_contact'), null, jsonb 'true');

select data.set_attribute_value(data.get_object_id('politicians'), data.get_attribute_id('system_priority'), null, jsonb '40');
select data.set_attribute_value(data.get_object_id('politicians'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('politicians'), data.get_attribute_id('name'), null, jsonb '"Политики"');

select data.set_attribute_value(data.get_object_id('medics'), data.get_attribute_id('system_priority'), null, jsonb '50');
select data.set_attribute_value(data.get_object_id('medics'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('medics'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('medics'), data.get_attribute_id('name'), null, jsonb '"Медицинский персонал"');
select data.set_attribute_value(data.get_object_id('medics'), data.get_attribute_id('system_mail_contact'), null, jsonb 'true');

select data.set_attribute_value(data.get_object_id('technicians'), data.get_attribute_id('system_priority'), null, jsonb '50');
select data.set_attribute_value(data.get_object_id('technicians'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('technicians'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('technicians'), data.get_attribute_id('name'), null, jsonb '"Технический персонал"');
select data.set_attribute_value(data.get_object_id('technicians'), data.get_attribute_id('system_mail_contact'), null, jsonb 'true');

select data.set_attribute_value(data.get_object_id('pilots'), data.get_attribute_id('system_priority'), null, jsonb '50');
select data.set_attribute_value(data.get_object_id('pilots'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('pilots'), data.get_attribute_id('name'), null, jsonb '"Пилоты"');

select data.set_attribute_value(data.get_object_id('officers'), data.get_attribute_id('system_priority'), null, jsonb '60');
select data.set_attribute_value(data.get_object_id('officers'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('officers'), data.get_attribute_id('name'), null, jsonb '"Офицеры"');

select data.set_attribute_value(data.get_object_id('hackers'), data.get_attribute_id('system_priority'), null, jsonb '80');
select data.set_attribute_value(data.get_object_id('hackers'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('hackers'), data.get_attribute_id('name'), null, jsonb '"Хакеры"');

select data.set_attribute_value(data.get_object_id('scientists'), data.get_attribute_id('system_priority'), null, jsonb '50');
select data.set_attribute_value(data.get_object_id('scientists'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('scientists'), data.get_attribute_id('name'), null, jsonb '"Учёные"');

select data.set_attribute_value(data.get_object_id('corporations'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('corporations'), data.get_attribute_id('system_meta'), data.get_object_id('masters'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('corporations'), data.get_attribute_id('type'), null, jsonb '"corporations"');
select data.set_attribute_value(data.get_object_id('corporations'), data.get_attribute_id('name'), null, jsonb '"Корпорации"');

select data.set_attribute_value(data.get_object_id('ships'), data.get_attribute_id('system_is_visible'), data.get_object_id('hackers'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('ships'), data.get_attribute_id('system_is_visible'), data.get_object_id('technicians'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('ships'), data.get_attribute_id('system_is_visible'), data.get_object_id('pilots'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('ships'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('ships'), data.get_attribute_id('name'), null, jsonb '"Корабли"');

select data.set_attribute_value(data.get_object_id('news_hub'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('news_hub'), data.get_attribute_id('system_meta'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('news_hub'), data.get_attribute_id('type'), null, jsonb '"news_hub"');
select data.set_attribute_value(data.get_object_id('news_hub'), data.get_attribute_id('name'), null, jsonb '"Новости"');

select
  data.set_attribute_value(data.get_object_id('media' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('media' || o.value), data.get_attribute_id('type'), null, jsonb '"media"'),
  data.set_attribute_value(data.get_object_id('media' || o.value), data.get_attribute_id('name'), null, to_jsonb('Media ' || o.value)),
  data.set_attribute_value(data.get_object_id('media' || o.value), data.get_attribute_id('description'), null, to_jsonb('Самая оперативная, честная и скромная из всех газет во всей вселенной. Читайте только нас! Мы - Media ' || o.value || '!'))
from generate_series(1, 3) o(value);

select
  data.set_attribute_value(data.get_object_id('race' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('race' || o.value), data.get_attribute_id('type'), null, jsonb '"race"'),
  data.set_attribute_value(data.get_object_id('race' || o.value), data.get_attribute_id('name'), null, to_jsonb('race' || o.value)),
  data.set_attribute_value(data.get_object_id('race' || o.value), data.get_attribute_id('description'), null, to_jsonb('Синие и ми-ми-мишные, а может быть зелёные и чешуйчатые, а может быть с костяным наростом, или они все Кош. Кто их знает этих представителей рассы №' || o.value || '!'))
from generate_series(1, 20) o(value);

select data.set_attribute_value(data.get_object_id('states'), data.get_attribute_id('system_meta'), data.get_object_id('masters'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('states'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('states'), data.get_attribute_id('type'), null, jsonb '"states"');
select data.set_attribute_value(data.get_object_id('states'), data.get_attribute_id('name'), null, jsonb '"Государства"');

select
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('type'), null, jsonb '"state"'),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('name'), null, to_jsonb('State ' || o.value)),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('system_balance'), null, to_jsonb(utils.random_integer(10000000,100000000))),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('description'), null, to_jsonb('Их адрес не дом и не улица, их адрес -  state ' || o.value || '!')),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('system_balance'), null, to_jsonb(utils.random_integer(100,100000000))),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('state_tax'), null, to_jsonb(o.value))
from generate_series(1, 10) o(value);

select data.set_attribute_value(data.get_object_id('anonymous'), data.get_attribute_id('system_priority'), null, jsonb '200');
select data.set_attribute_value(data.get_object_id('anonymous'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('anonymous'), data.get_attribute_id('type'), null, jsonb '"anonymous"');
select data.set_attribute_value(data.get_object_id('anonymous'), data.get_attribute_id('name'), null, jsonb '"Аноним"');
select data.set_attribute_value(data.get_object_id('anonymous'), data.get_attribute_id('description'), null, jsonb '"Вы не вошли в систему и работаете в режиме чтения общедоступной информации."');

select
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_priority'), null, jsonb '200'),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('type'), null, jsonb '"person"'),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('name'), null, to_jsonb('Person ' || o.value)),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_mail_contact'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('person_race'), null, to_jsonb('race' || (o.value % 20 + 1))),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('person_state'), null, to_jsonb('state' || (o.value % 10 + 1))),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('person_job_position'), null, jsonb '"Some job position"'),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('person_biography'), null, jsonb '"Born before 2250, currently live & work on Babylon 5"'),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_balance'), null, to_jsonb(utils.random_integer(100,10000000))),
  case when o.value % 10 = 0 then
    data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_psi_scale'), null, to_jsonb(utils.random_integer(1,16)))
  else
    null
  end,
  case when o.value > 51 then
    data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_master'), null, jsonb 'true')
  else
    null
  end,
  case when o.value % 11 = 0 then
    data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_medic'), null, jsonb 'true')
  else
    null
  end,
  case when o.value % 11 = 0 or o.value % 13 = 0 then
    data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_med_documents'), null, jsonb 'true')
  else
    null
  end,
  case when o.value % 13 = 0 then
    data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_security'), null, jsonb 'true')
  else
    null
  end
from generate_series(1, 60) o(value);

select data.set_attribute_value(data.get_object_id('market'), data.get_attribute_id('system_meta'), data.get_object_id('masters'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('market'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('market'), data.get_attribute_id('type'), null, jsonb '"market"');
select data.set_attribute_value(data.get_object_id('market'), data.get_attribute_id('name'), null, jsonb '"Рынок"');

select
  data.set_attribute_value(data.get_object_id('sector' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('sector' || o.value), data.get_attribute_id('type'), null, jsonb '"sector"'),
  data.set_attribute_value(data.get_object_id('sector' || o.value), data.get_attribute_id('name'), null, to_jsonb('Sector ' || o.value)),
  data.set_attribute_value(data.get_object_id('sector' || o.value), data.get_attribute_id('description'), null, to_jsonb('Описание рынка sector ' || o.value)),
  data.set_attribute_value(data.get_object_id('sector' || o.value), data.get_attribute_id('sector_volume'), null, to_jsonb(100000 * o.value)),
  data.set_attribute_value(data.get_object_id('sector' || o.value), data.get_attribute_id('sector_volume_changes'), null, jsonb '"2259.02.23 15:34 было 1000 стало 2000000000 - лучше стали жить<br> 2259.02.23 19:34 было 2000000000 стало 100000 - хуже стали жить"')
from generate_series(1, 4) o(value);

select
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('system_meta'), data.get_object_id('corporation' || o.value ), jsonb 'true'),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('type'), null, jsonb '"corporation"'),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('name'), null, to_jsonb('Corporation ' || o.value)),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('description'), null, to_jsonb('Описание корпорации corporation ' || o.value)),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('corporation_state'), null, to_jsonb('state' || (o.value % 10 + 1))),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('system_balance'), null, to_jsonb(utils.random_integer(100, 10000000))),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('corporation_sectors'), null, ('["sector' || (o.value % 3 + 1) || '", "sector' || (o.value % 3 + 2) || '"]')::jsonb),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('corporation_capitalization'), null, to_jsonb(10000000 + o.value)),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('system_corporation_members'), null, ('[{"member": "person' || o.value || '", "percent": 80}, {"member": "person' || (o.value * 2)::text || '", "percent": 20}]')::jsonb),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('system_corporation_deals'), null, ('["deal' || o.value || '", "deal' || (o.value + 1) || '"]')::jsonb),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('system_corporation_draft_deals'), null, ('["deal' || (10 + o.value) || '", "deal' || (10 + o.value + 1) || '"]')::jsonb),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('system_corporation_canceled_deals'), null, ('["deal' || (20 + o.value) || '", "deal' || (20 + o.value + 1) || '"]')::jsonb),
  data.set_attribute_value(data.get_object_id('corporation' || o.value), data.get_attribute_id('dividend_vote'), null, jsonb '"Нет"')
from generate_series(1, 11) o(value);

select data.set_attribute_value(data.get_object_id('normal_deals'), data.get_attribute_id('system_meta'), data.get_object_id('masters'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('normal_deals'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('normal_deals'), data.get_attribute_id('type'), null, jsonb '"normal_deals"');
select data.set_attribute_value(data.get_object_id('normal_deals'), data.get_attribute_id('name'), null, jsonb '"Активные сделки"');

select data.set_attribute_value(data.get_object_id('draft_deals'), data.get_attribute_id('system_meta'), data.get_object_id('masters'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('draft_deals'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('draft_deals'), data.get_attribute_id('type'), null, jsonb '"draft_deals"');
select data.set_attribute_value(data.get_object_id('draft_deals'), data.get_attribute_id('name'), null, jsonb '"Подготавливаемые сделки"');

select data.set_attribute_value(data.get_object_id('canceled_deals'), data.get_attribute_id('system_meta'), data.get_object_id('masters'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('canceled_deals'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('canceled_deals'), data.get_attribute_id('type'), null, jsonb '"canceled_deals"');
select data.set_attribute_value(data.get_object_id('canceled_deals'), data.get_attribute_id('name'), null, jsonb '"Расторгнутые сделки"');

select
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('type'), null, jsonb '"deal"'),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('name'), null, to_jsonb('Deal ' || o.value)),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('description'), null, to_jsonb('Описание сделки deal ' || o.value)),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('deal_sector'), null, to_jsonb('sector' || (o.value % 4 + 1))),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('asset_name'), null, to_jsonb('Актив сделки deal' || o.value)),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('asset_cost'), null, to_jsonb(o.value * 1000)),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('asset_amortization'), null, to_jsonb(o.value * 100)),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('deal_income'), null, to_jsonb(o.value * 10)),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('system_deal_participant1'), null, ('{"member" : "corporation' || (o.value % 10 + 1) || '", "percent_asset": 80, "percent_income": 30, "deal_cost": 10000}')::jsonb),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('system_deal_participant2'), null, ('{"member" : "corporation' || (o.value % 10 + 2) || '", "percent_asset": 20, "percent_income": 70, "deal_cost": 50000}')::jsonb)
from generate_series(1, 30) o(value);

select
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('system_deal_time'), null, to_jsonb('2259.02.23 15:' || (o.value + 10))),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('deal_time'), null, to_jsonb('2259.02.23 15:' || (o.value + 10))),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('deal_status'), null, jsonb '"normal"')
from generate_series(1, 10) o(value);

select
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('system_deal_time'), null, to_jsonb('2259.02.23 12:' || (o.value + 10))),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('deal_status'), null, jsonb '"draft"'),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('deal_author'), null, to_jsonb(data.get_object_id('person1')))
from generate_series(11, 20) o(value);

select
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('system_deal_time'), null, to_jsonb('2259.02.23 18:' || (o.value + 10))),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('deal_time'), null, to_jsonb('2259.02.23 15:' || (o.value + 10))),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('deal_cancel_time'), null, to_jsonb('2259.02.23 18:' || (o.value + 10))),
  data.set_attribute_value(data.get_object_id('deal' || o.value), data.get_attribute_id('deal_status'), null, jsonb '"canceled"')
from generate_series(21, 30) o(value);

-- other person{1,60}
/*
system_politician
system_technician
system_pilot
system_officer
system_hacker
system_scientist
*/

select
  data.set_attribute_value(data.get_object_id('global_notification' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('global_notification' || o.value), data.get_attribute_id('notification_description'), null, to_jsonb('Global notification ' || o.value)),
  data.set_attribute_value(data.get_object_id('global_notification' || o.value), data.get_attribute_id('notification_time'), null, to_jsonb('15.02.2258 17:2' || o.value)),
  data.set_attribute_value(data.get_object_id('global_notification' || o.value), data.get_attribute_id('notification_status'), null, jsonb '"unread"'),
  data.set_attribute_value(data.get_object_id('global_notification' || o.value), data.get_attribute_id('type'), null, jsonb '"notification"')
from generate_series(1, 3) o(value);

select
  data.set_attribute_value(data.get_object_id('personal_notification' || o.value), data.get_attribute_id('system_is_visible'), data.get_object_id('person' || o.value), jsonb 'true'),
  data.set_attribute_value(data.get_object_id('personal_notification' || o.value), data.get_attribute_id('notification_description'), null, to_jsonb('Personal notification ' || o.value)),
  data.set_attribute_value(data.get_object_id('personal_notification' || o.value), data.get_attribute_id('notification_object_code'), null, to_jsonb('person' || o.value)),
  data.set_attribute_value(data.get_object_id('personal_notification' || o.value), data.get_attribute_id('notification_time'), null, jsonb '"15.02.2258 17:30"'),
  data.set_attribute_value(data.get_object_id('personal_notification' || o.value), data.get_attribute_id('notification_status'), null, jsonb '"unread"'),
  data.set_attribute_value(data.get_object_id('personal_notification' || o.value), data.get_attribute_id('type'), null, jsonb '"notification"')
from generate_series(1, 60) o(value);

select data.set_attribute_value(data.get_object_id('person' || o.pn), data.get_attribute_id('notifications'), data.get_object_id('person' || o.pn), jsonb_agg(o.code))
from (
  select o1.value pn, 'global_notification' || o2.value as code
  from generate_series(1, 60) o1(value)
  join generate_series(1, 3) o2(value) on 1=1
  union
  select o1.value pn, 'personal_notification' || o1.value
  from generate_series(1, 60) o1(value)
) o
group by o.pn;

select data.set_attribute_value(data.get_object_id('anonymous'), data.get_attribute_id('notifications'), data.get_object_id('anonymous'), jsonb_agg('global_notification' || o.value))
from generate_series(1, 3) o(value);

select
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('type'), null, jsonb '"news"'),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('news_title'), null, to_jsonb('Заголовок новости news' || o1.value || o2.value || '!')),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('name'), null, to_jsonb('media'||o1.value||': Заголовок новости news' || o1.value || o2.value || '!')),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('news_media'), null, to_jsonb('media' || o1.value)),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('system_news_time'), null, to_jsonb('2258.02.23 ' || 10 + trunc(o2.value / 10) || ':' || 10 + o1.value * 5)),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('news_time'), null, to_jsonb('23.02.2258 ' || 10 + trunc(o2.value / 10) || ':' || 10 + o1.value * 5)),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('content'), null, to_jsonb('Текст новости news' || o1.value || o2.value || '. <br>После активного культурного взаимонасыщения таких, казалось бы разных цивилизаций, как Драззи и Минбари их общества кардинально изменились. Ввиду закрытости последних, стороннему наблюдателю, скорей всего не суждено узнать, как же повлияли воинственные Драззи на высокодуховных Минбарцев, однако у первых изменения, так сказать, на лицо. <br>Почти сразу после первых визитов, спрос на минбарскую культуру взлетел до небес! Ткани, одежда, предметы мебели и прочие диковинные товары заполонили рынки. Активно стали ввозиться всевозможные составы целительного свойства. Например, ставший знаменитым порошок, под названием “Минбарский гребень” завоевал популярность у молодых Драззи. Препарат, якобы, сделан на основе тертого костного образования на черепе минбарца. Многие потребители уверяют, что с его помощью, смогли одержать победу на любовном фронте, однако, ученые уверяют, что тонизирующий эффект, как и происхождение самого препарата не вызывают особого доверия.'))
from generate_series(1, 3) o1(value)
join generate_series(1, 100) o2(value) on 1=1;

select data.set_attribute_value(data.get_object_id('transactions'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('transactions'), data.get_attribute_id('type'), null, jsonb '"transactions"');
select data.set_attribute_value(data.get_object_id('transactions'), data.get_attribute_id('name'), null, jsonb '"История операций"');
select data.set_attribute_value(data.get_object_id('transactions'), data.get_attribute_id('system_meta'), data.get_object_id('persons'), jsonb 'true');

select data.set_attribute_value(data.get_object_id('mailbox'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('mailbox'), data.get_attribute_id('type'), null, jsonb '"mailbox"');
select data.set_attribute_value(data.get_object_id('mailbox'), data.get_attribute_id('name'), null, jsonb '"Почта"');
select data.set_attribute_value(data.get_object_id('mailbox'), data.get_attribute_id('system_meta'), data.get_object_id('persons'), jsonb 'true');

select data.set_attribute_value(data.get_object_id('inbox'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('inbox'), data.get_attribute_id('system_mail_folder_type'), null, jsonb '"inbox"');
select data.set_attribute_value(data.get_object_id('inbox'), data.get_attribute_id('type'), null, jsonb '"mail_folder"');
select data.set_attribute_value(data.get_object_id('inbox'), data.get_attribute_id('name'), null, jsonb '"Входящие"');

select data.set_attribute_value(data.get_object_id('outbox'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('outbox'), data.get_attribute_id('system_mail_folder_type'), null, jsonb '"outbox"');
select data.set_attribute_value(data.get_object_id('outbox'), data.get_attribute_id('type'), null, jsonb '"mail_folder"');
select data.set_attribute_value(data.get_object_id('outbox'), data.get_attribute_id('name'), null, jsonb '"Исходящие"');

select data.set_attribute_value(data.get_object_id('med_library'), data.get_attribute_id('system_is_visible'), data.get_object_id('med_documents'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('med_library'), data.get_attribute_id('system_is_visible'), data.get_object_id('masters'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('med_library'), data.get_attribute_id('type'), null, jsonb '"med_library"');
select data.set_attribute_value(data.get_object_id('med_library'), data.get_attribute_id('name'), null, jsonb '"Медицинские отчёты"');
select data.set_attribute_value(data.get_object_id('med_library'), data.get_attribute_id('system_meta'), data.get_object_id('med_documents'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('med_library'), data.get_attribute_id('system_meta'), data.get_object_id('masters'), jsonb 'true');

select
  data.set_attribute_value(data.get_object_id('med_document' || o.value), data.get_attribute_id('system_is_visible'), data.get_object_id('med_documents'), jsonb 'true'),
  data.set_attribute_value(data.get_object_id('med_document' || o.value), data.get_attribute_id('system_is_visible'), data.get_object_id('masters'), jsonb 'true'),
  data.set_attribute_value(data.get_object_id('med_document' || o.value), data.get_attribute_id('type'), null, jsonb '"med_document"'),
  data.set_attribute_value(data.get_object_id('med_document' || o.value), data.get_attribute_id('name'), null, to_jsonb('Медицинский отчёт ' || o.value)),
  data.set_attribute_value(data.get_object_id('med_document' || o.value), data.get_attribute_id('document_title'), null, to_jsonb('Медицинский отчёт ' || o.value)),
  data.set_attribute_value(data.get_object_id('med_document' || o.value), data.get_attribute_id('system_document_time'), null, to_jsonb(case when o.value < 10 then '0' else '' end || o.value)),
  data.set_attribute_value(data.get_object_id('med_document' || o.value), data.get_attribute_id('document_time'), null, to_jsonb('19.02.2258 17:' || case when o.value < 10 then '0' else '' end || o.value)),
  data.set_attribute_value(data.get_object_id('med_document' || o.value), data.get_attribute_id('content'), null, to_jsonb('Содержимое медицинского отчёта ' || o.value)),
  data.set_attribute_value(data.get_object_id('med_document' || o.value), data.get_attribute_id('document_author'), null, to_jsonb('person' || ((o.value % 5 + 1) * 11))),
  data.set_attribute_value(data.get_object_id('med_document' || o.value), data.get_attribute_id('med_document_patient'), null, to_jsonb('person' || (o.value + (o.value - 1) / 10)))
from generate_series(1, 15) o(value);

  -- TODO: Всё прочее
/*
system_priority
system_is_visible
type
name
description
content
system_value
meta_entities
system_meta
system_mail_contact
person_race
person_state
person_job_position
person_biography
person_psi_scale
mail_title
system_mail_send_time
mail_send_time
mail_author
mail_receivers
mail_body
mail_type
inbox
outbox
corporation_members
corporation_capitalization
corporation_assets
asset_corporations
asset_time
asset_status
asset_cost
market_volume
system_balance
balance
system_master
system_security
system_politician
system_medic
system_technician
system_pilot
system_officer
system_hacker
system_scientist
system_library_category
*/
/*
personal_document_storage
library
personal_library
station
station_medlab
station_lab
station_radar
station_power_computer
station_hacker_computer
ship
ship_radar
ship_power_computer
ship_hacker_computer
assembly
meta_entities
station_weapon{1,4}
station_reactor{1,4}
ship_weapon{1,2}
ship_reactor{1,2}
library_category{1,9}
library_document{1,9}{1,20}
personal_document{1,100}
*/

-- TODO: Много разных действий
--   Письма
--   Транзакции

-- Логины
insert into data.logins(code, description)
select 'player' || o.value || '_code', 'player' || o.value from generate_series(1, 50) o(value);

insert into data.logins(code, description, is_admin)
select 'master' || o.value || '_code', 'master' || o.value, true from generate_series(1, 5) o(value);

-- Связи клиентов и логинов
select data.set_client_login('client' || o.value, l.id)
from generate_series(1, 50) o(value)
join data.logins l on
  l.description = 'player' || o.value;

select data.set_client_login('client' || (o.value + 50), l.id)
from generate_series(1, 10) o(value)
join data.logins l on
  l.description = 'master' || o.value;

-- Связи логинов и объектов
select data.add_object_to_login(data.get_object_id('person51'), id)
from data.logins
where description = 'player50';

select data.add_object_to_login(data.get_object_id('person' || o.value), l.id)
from generate_series(1, 50) o(value)
join data.logins l on
  l.description = 'player' || o.value;

select data.add_object_to_login(data.get_object_id('anonymous'), id)
from data.logins
where id = data.get_integer_param('default_login');

select data.add_object_to_login(data.get_object_id('person' || o1.value), l.id)
from generate_series(52, 60) o1(value)
join generate_series(1, 5) o2(value) on 1=1
join data.logins l on
  l.description = 'master' || o2.value;

-- Действие для привязки клиента к логину
CREATE OR REPLACE FUNCTION action_generators.login(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_user_object_id integer;
  v_test_object_id integer;
begin
  if v_object_id is not null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
  v_test_object_id := json.get_integer(in_params, 'test_object_id');

  if v_user_object_id != v_test_object_id then
    return null;
  end if;

  return jsonb_build_object(
    'login',
    jsonb_build_object(
      'code', 'login',
      'name', 'Вход в систему',
      'type', 'security.login',
      'params', jsonb '{}',
      'user_params',
        jsonb_build_array(
          jsonb_build_object(
            'code', 'password',
            'type', 'string',
            'data', jsonb_build_object('min_length', 1),
            'description', 'Персональный код',
            'min_value_count', 1,
            'max_value_count', 1))));
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.login(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_password text := json.get_string(in_user_params, 'password');
  v_login_id integer;
begin
  select id
  into v_login_id
  from data.logins
  where code = v_password
  for share;

  if v_login_id is null then
    return api_utils.create_ok_result(null, 'Неправильный персональный код!');
  end if;

  perform data.set_client_login(in_client, v_login_id, in_user_object_id, 'Вход в систему');

  return api_utils.create_ok_result(null);
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('login', jsonb_build_object('test_object_id', data.get_object_id('anonymous')), 'Функция входа в систему');

-- "Выход"
CREATE OR REPLACE FUNCTION action_generators.logout(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_user_object_id integer;
  v_test_object_id integer;
begin
  if v_object_id is not null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
  v_test_object_id := json.get_integer(in_params, 'test_object_id');

  if v_user_object_id = v_test_object_id then
    return null;
  end if;

  return jsonb_build_object(
    'logout',
    jsonb_build_object(
      'code', 'logout',
      'name', 'Выйти',
      'type', 'security.logout',
      'params', jsonb '{}',
      'warning', jsonb '"Вы действительно хотите выйти?"'));
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.logout(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
begin
  perform data.set_client_login(in_client, null, in_user_object_id);

  return api_utils.create_ok_result(null);
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('logout', jsonb_build_object('test_object_id', data.get_object_id('anonymous')), 'Функция выхода из системы');

-- Действие для изменения статуса уведомления на "прочитано"
CREATE OR REPLACE FUNCTION action_generators.read_notification(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
begin
  return jsonb_build_object(
    'read_notification',
    jsonb_build_object(
      'code', 'read_notification',
      'name', 'Отметить как прочитанное',
      'type', 'notifications.read',
      'params', jsonb_build_object('notification_code', data.get_object_code(json.get_integer(in_params, 'object_id')))));
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.read_notification(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_notification_id integer := data.get_object_id(json.get_string(in_params, 'notification_code'));
  v_notification_status_attribute_id integer := data.get_attribute_id('notification_status');
begin
  perform data.set_attribute_value_if_changed(
    v_notification_id,
    v_notification_status_attribute_id,
    in_user_object_id,
    jsonb '"read"',
    in_user_object_id);

  return api_utils.create_ok_result(null);
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_attribute', jsonb_build_object('attribute_code', 'notification_status', 'attribute_value', 'unread', 'function', 'read_notification'), 'Функция для пометки уведомления как прочтённого');

-- Функция для создания уведомления
CREATE OR REPLACE FUNCTION actions.create_notification(
    in_user_object_id integer,
    in_object_ids integer[],
    in_description text,
    in_notification_object_code text,
    in_days_shift integer DEFAULT NULL::integer)
  RETURNS void AS
$BODY$
declare
  v_notification_id integer;
  v_notification_code text;
  v_object_id integer;
  v_notification_attribute_id integer := data.get_attribute_id('notifications');
  v_old_notifications jsonb;
begin
  assert in_user_object_id is not null;
  assert in_object_ids is not null;
  assert in_description is not null;

  insert into data.objects(id) values(default)
  returning id, code into v_notification_id, v_notification_code;

  perform data.set_attribute_value(v_notification_id, data.get_attribute_id('system_is_visible'), null, jsonb 'true', in_user_object_id);
  perform data.set_attribute_value(v_notification_id, data.get_attribute_id('notification_description'), null, to_jsonb(in_description), in_user_object_id);
  if in_notification_object_code is not null then
    perform data.set_attribute_value(v_notification_id, data.get_attribute_id('notification_object_code'), null, to_jsonb(in_notification_object_code), in_user_object_id);
  end if;
  perform data.set_attribute_value(v_notification_id, data.get_attribute_id('notification_time'), null, to_jsonb(utils.current_time(in_days_shift)), in_user_object_id);
  perform data.set_attribute_value(v_notification_id, data.get_attribute_id('notification_status'), null, jsonb '"unread"', in_user_object_id);
  perform data.set_attribute_value(v_notification_id, data.get_attribute_id('type'), null, jsonb '"notification"', in_user_object_id);

  in_object_ids := intarray.uniq(intarray.sort(in_object_ids));

  foreach v_object_id in array in_object_ids loop
    v_old_notifications := data.get_attribute_value_for_update(v_object_id, v_notification_attribute_id, v_object_id);
    perform json.get_opt_string_array(v_old_notifications);

    perform data.set_attribute_value(
      v_object_id,
      v_notification_attribute_id,
      v_object_id,
      coalesce(v_old_notifications, jsonb '[]') || jsonb_build_array(v_notification_code),
      in_user_object_id);
  end loop;
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

-- Функция для создания транзакции
CREATE OR REPLACE FUNCTION actions.create_transaction(
    in_user_object_id integer,
    in_sender_id integer,
    in_object_id integer,
    in_description text,
    in_sum integer,
    in_sender_rest integer,
    in_receiver_rest integer,
    add_sender_to_transation boolean)
  RETURNS void AS
$BODY$
declare
  v_transaction_id integer;
  v_transaction_code text;
  v_transactions_value jsonb;
  v_transactions_object_id integer := data.get_object_id('transactions');
  v_transactions_system_value_attribute_id integer := data.get_attribute_id('system_value');
begin
  assert in_user_object_id is not null;
  assert in_object_id is not null;
  assert in_description is not null;
  assert in_sum > 0;
  assert not add_sender_to_transation or in_sender_rest >= 0;
  assert in_receiver_rest >= 0;
  assert add_sender_to_transation is not null;

  insert into data.objects(id) values(default)
  returning id, code into v_transaction_id, v_transaction_code;

  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('system_is_visible'), in_sender_id, jsonb 'true', in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('system_is_visible'), in_object_id, jsonb 'true', in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('system_is_visible'), data.get_object_id('masters'), jsonb 'true', in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('type'), null, jsonb '"transaction"', in_user_object_id);
  if add_sender_to_transation then
    perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('transaction_from'), null, to_jsonb(data.get_object_code(in_sender_id)), in_user_object_id);
  end if;
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('transaction_to'), null, to_jsonb(data.get_object_code(in_object_id)), in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('transaction_time'), null, to_jsonb(utils.current_time()), in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('transaction_description'), null, to_jsonb(in_description), in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('transaction_sum'), null, to_jsonb(in_sum), in_user_object_id);
  if add_sender_to_transation then
    perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('balance_rest'), in_sender_id, to_jsonb(in_sender_rest), in_user_object_id);
  end if;
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('balance_rest'), in_object_id, to_jsonb(in_receiver_rest), in_user_object_id);

  v_transactions_value := data.get_attribute_value_for_update(v_transactions_object_id, v_transactions_system_value_attribute_id, in_sender_id);
  perform json.get_opt_string_array(v_transactions_value);

  v_transactions_value := coalesce(v_transactions_value, jsonb '[]') || jsonb_build_array(v_transaction_code);
  perform data.set_attribute_value(v_transactions_object_id, v_transactions_system_value_attribute_id, in_sender_id, v_transactions_value, in_user_object_id);

  v_transactions_value := data.get_attribute_value_for_update(v_transactions_object_id, v_transactions_system_value_attribute_id, in_object_id);
  perform json.get_opt_string_array(v_transactions_value);

  v_transactions_value := coalesce(v_transactions_value, jsonb '[]') || jsonb_build_array(v_transaction_code);
  perform data.set_attribute_value(v_transactions_object_id, v_transactions_system_value_attribute_id, in_object_id, v_transactions_value, in_user_object_id);
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

-- Действия для перечисления денег
CREATE OR REPLACE FUNCTION actions.transfer(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_receiver_id integer := data.get_object_id(json.get_string(in_user_params, 'receiver'));
  v_description text := json.get_string(in_user_params, 'description');
  v_sum integer := json.get_integer(in_user_params, 'sum');

  v_system_balance_attribute_id integer := data.get_attribute_id('system_balance');
  v_user_balance integer;
  v_receiver_balance integer;

  v_ret_val api.result;
begin
  assert in_user_object_id is not null;
  assert in_user_object_id != v_receiver_id;
  assert v_sum > 0;

  if in_user_object_id < v_receiver_id then
    v_user_balance := data.get_attribute_value_for_update(in_user_object_id, v_system_balance_attribute_id, null);
    v_receiver_balance := data.get_attribute_value_for_update(v_receiver_id, v_system_balance_attribute_id, null);
  else
    v_receiver_balance := data.get_attribute_value_for_update(v_receiver_id, v_system_balance_attribute_id, null);
    v_user_balance := data.get_attribute_value_for_update(in_user_object_id, v_system_balance_attribute_id, null);
  end if;

  if coalesce(v_user_balance, 0) < v_sum then
    v_ret_val := api_utils.get_objects(
      in_client,
      in_user_object_id,
      jsonb_build_object(
        'object_codes', jsonb_build_array(data.get_object_code(in_user_object_id)),
        'get_actions', true,
        'get_templates', true));
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Недостаточно средств!"}';
    return v_ret_val;
  end if;

  perform data.set_attribute_value(
    in_user_object_id,
    v_system_balance_attribute_id,
    null,
    to_jsonb(v_user_balance - v_sum),
    in_user_object_id,
    'Перевод средств пользователю ' || v_receiver_id);
  perform data.set_attribute_value(
    v_receiver_id,
    v_system_balance_attribute_id,
    null,
    to_jsonb(v_receiver_balance + v_sum),
    in_user_object_id,
    'Перевод средств от пользователя ' || in_user_object_id);

  perform actions.create_transaction(
    in_user_object_id,
    in_user_object_id,
    v_receiver_id,
    v_description,
    v_sum,
    v_user_balance - v_sum,
    v_receiver_balance + v_sum,
    true);

  perform actions.create_notification(
    in_user_object_id,
    array[v_receiver_id],
    (
      'Входящий перевод на сумму ' ||
      v_sum ||
      '.<br>Остаток: ' ||
      (v_receiver_balance + v_sum) ||
      '.<br>Отправитель: ' ||
      coalesce(
        json.get_opt_string(data.get_attribute_value(v_receiver_id, in_user_object_id, data.get_attribute_id('name'))),
        'Неизвестный') ||
      '.<br>Сообщение: ' ||
      v_description
    ),
    'transactions');

  return api_utils.get_objects(
    in_client,
    in_user_object_id,
    jsonb_build_object(
      'object_codes', jsonb '["transactions"]',
      'get_actions', true,
      'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

CREATE OR REPLACE FUNCTION action_generators.transfer(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_type_attr_id integer;
  v_type text;
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_system_balance_attribute_id integer;
  v_balance jsonb;
  v_balance_value integer;
begin
  if v_object_id is not null then
    if v_object_id = v_user_object_id then
      return null;
    end if;

    v_type_attr_id := data.get_attribute_id('type');

    select json.get_string(value)
    into v_type
    from data.attribute_values
    where
      object_id = v_object_id and
      attribute_id = v_type_attr_id and
      value_object_id is null;

    if v_type not in ('person', 'state', 'corporation') then
      return null;
    end if;
  end if;

  v_system_balance_attribute_id := data.get_attribute_id('system_balance');

  select value
  into v_balance
  from data.attribute_values
  where
    object_id = v_user_object_id and
    attribute_id = v_system_balance_attribute_id and
    value_object_id is null;

  if v_balance is not null then
    v_balance_value := json.get_integer(v_balance);
  end if;

  if v_balance is null or v_balance_value <= 0 then
    return jsonb_build_object(
      'transfer',
      jsonb_build_object(
        'code', 'transfer',
        'name', 'Создать перевод',
        'type', 'finances.transfer',
        'disabled', true));
  end if;

  return jsonb_build_object(
    'transfer',
    jsonb_build_object(
      'code', 'transfer',
      'name',
      case when v_object_id is null then
        'Создать перевод'
      when v_type = 'state' then
        'Перевести средства на счёт государства'
      when v_type = 'corporation' then
        'Перевести средства на счёт корпорации'
      else
        'Создать перевод'
      end,
      'type', 'finances.transfer',
      'user_params',
      jsonb_build_array(
        jsonb_build_object(
          'code', 'receiver',
          'type', 'objects',
          'data', jsonb_build_object('object_code', 'transaction_destinations', 'attribute_code', 'transaction_destinations'),
          'description', 'Получатель',
          'min_value_count', 1,
          'max_value_count', 1) ||
        case when v_object_id is not null then
          jsonb_build_object('default_value', data.get_object_code(v_object_id))
        else
          jsonb '{}'
        end,
        jsonb_build_object(
          'code', 'description',
          'type', 'string',
          'data', jsonb_build_object('min_length', '1'),
          'description', 'Назначение перевода',
          'min_value_count', 1,
          'max_value_count', 1),
        jsonb_build_object(
          'code', 'sum',
          'type', 'integer',
          'data', jsonb_build_object('min_value', 1, 'max_value', v_balance_value),
          'description', 'Сумма',
          'min_value_count', 1,
          'max_value_count', 1))));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_user_attribute', jsonb_build_object('attribute_code', 'type', 'attribute_value', 'person', 'function', 'transfer'), 'Функция для перевода средств');

-- Действие для перевода денег государства
CREATE OR REPLACE FUNCTION actions.state_money_transfer(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_receiver_id integer := data.get_object_id(json.get_string(in_user_params, 'receiver'));
  v_description text := json.get_string(in_user_params, 'description');
  v_sum integer := json.get_integer(in_user_params, 'sum');
  v_state_code text := json.get_string(in_params, 'state_code');
  v_state_id integer := data.get_object_id(v_state_code);

  v_is_in_state boolean;

  v_system_balance_attribute_id integer := data.get_attribute_id('system_balance');
  v_state_balance integer;
  v_receiver_balance integer;

  v_ret_val api.result;
begin
  assert in_user_object_id is not null;
  assert in_user_object_id != v_receiver_id;
  assert v_sum > 0;

  select true
  into v_is_in_state
  where exists(
    select 1
    from data.object_objects
    where
      parent_object_id = v_state_id and
      object_id = in_user_object_id);

  if v_is_in_state is null then
    v_ret_val := api_utils.get_objects(
      in_client,
      in_user_object_id,
      jsonb_build_object(
        'object_codes', jsonb_build_array(v_state_code),
        'get_actions', true,
        'get_templates', true));
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Вы не можете распоряжаться средствами данного государства!"}';
    return v_ret_val;
  end if;

  if v_state_id < v_receiver_id then
    v_state_balance := data.get_attribute_value_for_update(v_state_id, v_system_balance_attribute_id, null);
    v_receiver_balance := data.get_attribute_value_for_update(v_receiver_id, v_system_balance_attribute_id, null);
  else
    v_receiver_balance := data.get_attribute_value_for_update(v_receiver_id, v_system_balance_attribute_id, null);
    v_state_balance := data.get_attribute_value_for_update(v_state_id, v_system_balance_attribute_id, null);
  end if;

  if coalesce(v_state_balance, 0) < v_sum then
    v_ret_val := api_utils.get_objects(
      in_client,
      in_user_object_id,
      jsonb_build_object(
        'object_codes', jsonb_build_array(v_state_code),
        'get_actions', true,
        'get_templates', true));
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Недостаточно средств!"}';
    return v_ret_val;
  end if;

  perform data.set_attribute_value(
    v_state_id,
    v_system_balance_attribute_id,
    null,
    to_jsonb(v_state_balance - v_sum),
    in_user_object_id,
    'Перевод средств пользователю ' || v_receiver_id);
  perform data.set_attribute_value(
    v_receiver_id,
    v_system_balance_attribute_id,
    null,
    to_jsonb(v_receiver_balance + v_sum),
    in_user_object_id,
    'Перевод средств от государства ' || v_state_id);

  perform actions.create_transaction(
    in_user_object_id,
    v_state_id,
    v_receiver_id,
    v_description,
    v_sum,
    v_state_balance - v_sum,
    v_receiver_balance + v_sum,
    true);

  perform actions.create_notification(
    in_user_object_id,
    array[v_receiver_id],
    (
      'Входящий перевод на сумму ' ||
      v_sum ||
      '.<br>Остаток: ' ||
      (v_receiver_balance + v_sum) ||
      '.<br>Отправитель: ' ||
      coalesce(
        json.get_opt_string(data.get_attribute_value(v_receiver_id, v_state_id, data.get_attribute_id('name'))),
        'Неизвестный') ||
      '.<br>Сообщение: ' ||
      v_description
    ),
    'transactions');

  return api_utils.get_objects(
    in_client,
    in_user_object_id,
    jsonb_build_object(
      'object_codes', jsonb_build_array(v_state_code),
      'get_actions', true,
      'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

CREATE OR REPLACE FUNCTION action_generators.state_money_transfer(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_system_balance_attribute_id integer := data.get_attribute_id('system_balance');
  v_balance jsonb;
  v_balance_value integer;
begin
  select value
  into v_balance
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_system_balance_attribute_id and
    value_object_id is null;

  if v_balance is not null then
    v_balance_value := json.get_integer(v_balance);
  end if;

  if v_balance is null or v_balance_value <= 0 then
    return jsonb_build_object(
      'state_money_transfer',
      jsonb_build_object(
        'code', 'state_money_transfer',
        'name', 'Перевести средства со счёта государства',
        'type', 'finances.transfer',
        'disabled', true));
  end if;

  return jsonb_build_object(
    'state_money_transfer',
    jsonb_build_object(
      'code', 'state_money_transfer',
      'name', 'Перевести средства со счёта государства',
      'type', 'finances.transfer',
      'params', jsonb_build_object('state_code', data.get_object_code(v_object_id)),
      'user_params',
      jsonb_build_array(
        jsonb_build_object(
          'code', 'receiver',
          'type', 'objects',
          'data', jsonb_build_object('object_code', 'transaction_destinations', 'attribute_code', 'transaction_destinations'),
          'description', 'Получатель',
          'min_value_count', 1,
          'max_value_count', 1),
        jsonb_build_object(
          'code', 'description',
          'type', 'string',
          'data', jsonb_build_object('min_length', '1'),
          'description', 'Назначение перевода',
          'min_value_count', 1,
          'max_value_count', 1),
        jsonb_build_object(
          'code', 'sum',
          'type', 'integer',
          'data', jsonb_build_object('min_value', 1, 'max_value', v_balance_value),
          'description', 'Сумма',
          'min_value_count', 1,
          'max_value_count', 1))));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

insert into data.action_generators(function, params, description)
values(
  'generate_if_attribute',
  jsonb '{
    "attribute_code": "type",
    "attribute_value": "state",
    "function": "generate_if_in_object",
    "params": {
      "function": "state_money_transfer"
    }
  }',
  'Функция для перевода средств');

-- Действие для добавления денег
CREATE OR REPLACE FUNCTION actions.generate_money(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_receiver_id integer := data.get_object_id(json.get_string(in_user_params, 'receiver'));
  v_description text := json.get_string(in_user_params, 'description');
  v_sum integer := json.get_integer(in_user_params, 'sum');

  v_system_balance_attribute_id integer := data.get_attribute_id('system_balance');
  v_receiver_balance integer;
begin
  assert in_user_object_id is not null;
  assert v_sum > 0;

  v_receiver_balance := data.get_attribute_value_for_update(v_receiver_id, v_system_balance_attribute_id, null);

  perform data.set_attribute_value(
    v_receiver_id,
    v_system_balance_attribute_id,
    null,
    to_jsonb(v_receiver_balance + v_sum),
    in_user_object_id,
    'Добавление средств мастером');

  perform actions.create_transaction(
    in_user_object_id,
    in_user_object_id,
    v_receiver_id,
    v_description,
    v_sum,
    null,
    v_receiver_balance + v_sum,
    false);

  perform actions.create_notification(
    in_user_object_id,
    array[v_receiver_id],
    (
      'Входящий перевод на сумму ' ||
      v_sum ||
      '.<br>Остаток: ' ||
      (v_receiver_balance + v_sum) ||
      '.<br>Сообщение: ' ||
      v_description
    ),
    'transactions');

  return api_utils.get_objects(
    in_client,
    in_user_object_id,
    jsonb_build_object(
      'object_codes', jsonb '["transactions"]',
      'get_actions', true,
      'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE OR REPLACE FUNCTION action_generators.generate_money(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_type_attr_id integer;
  v_type text;
  v_user_object_id integer;
begin
  if v_object_id is not null then
    v_type_attr_id := data.get_attribute_id('type');

    select json.get_string(value)
    into v_type
    from data.attribute_values
    where
      object_id = v_object_id and
      attribute_id = v_type_attr_id and
      value_object_id is null;

    if v_type not in ('person', 'state', 'corporation') then
      return null;
    end if;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');

  return jsonb_build_object(
    'generate_money',
    jsonb_build_object(
      'code', 'generate_money',
      'name', 'Добавить средств',
      'type', 'cheats.money_generation',
      'user_params',
      jsonb_build_array(
        jsonb_build_object(
          'code', 'receiver',
          'type', 'objects',
          'data', jsonb_build_object('object_code', 'transaction_destinations', 'attribute_code', 'transaction_destinations'),
          'description', 'Получатель',
          'min_value_count', 1,
          'max_value_count', 1) ||
        case when v_object_id is not null then
          jsonb_build_object('default_value', data.get_object_code(v_object_id))
        else
          jsonb '{}'
        end,
        jsonb_build_object(
          'code', 'description',
          'type', 'string',
          'data', jsonb_build_object('min_length', '1'),
          'description', 'Назначение перевода',
          'min_value_count', 1,
          'max_value_count', 1),
        jsonb_build_object(
          'code', 'sum',
          'type', 'integer',
          'data', jsonb_build_object('min_value', 1),
          'description', 'Сумма',
          'min_value_count', 1,
          'max_value_count', 1))));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_user_attribute', jsonb_build_object('attribute_code', 'system_master', 'attribute_value', true, 'function', 'generate_money'), 'Функция для добавления средств');

-- Действие для создания медицинского отчёта
CREATE OR REPLACE FUNCTION action_generators.create_med_document(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_user_object_id integer;
  v_medics_objects_id integer;
  v_medic boolean;
begin
  if v_object_id is not null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
  v_medics_objects_id := data.get_object_id('medics');

  select true
  into v_medic
  where exists(
    select 1
    from data.object_objects
    where
      parent_object_id = v_medics_objects_id and
      object_id = v_user_object_id);

  if v_medic is null then
    return null;
  end if;

  return jsonb_build_object(
    'create_med_document',
    jsonb_build_object(
      'code', 'create_med_document',
      'name', 'Создать медицинский отчёт',
      'type', 'documents.create',
      'params', jsonb '{}',
      'user_params',
        jsonb_build_array(
          jsonb_build_object(
            'code', 'patient',
            'type', 'objects',
            'data', jsonb_build_object('object_code', 'persons', 'attribute_code', 'persons'),
            'description', 'Пациент',
            'min_value_count', 1,
            'max_value_count', 1),
          jsonb_build_object(
            'code', 'title',
            'type', 'string',
            'data', jsonb_build_object('min_length', 1),
            'description', 'Заголовок',
            'min_value_count', 1,
            'max_value_count', 1),
          jsonb_build_object(
            'code', 'content',
            'type', 'string',
            'data', jsonb_build_object('min_length', 1, 'multiline', true),
            'description', 'Содержимое',
            'min_value_count', 1,
            'max_value_count', 1))));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.create_med_document(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_patient text := json.get_string(in_user_params, 'patient');
  v_title text := json.get_string(in_user_params, 'title');
  v_content text := json.get_string(in_user_params, 'content');

  v_document_id integer;
  v_document_code text;
begin
  insert into data.objects(id) values(default)
  returning id, code into v_document_id, v_document_code;

  perform data.set_attribute_value(v_document_id, data.get_attribute_id('system_is_visible'), data.get_object_id('med_documents'), jsonb 'true');
  perform data.set_attribute_value(v_document_id, data.get_attribute_id('system_is_visible'), data.get_object_id('masters'), jsonb 'true');
  perform data.set_attribute_value(v_document_id, data.get_attribute_id('type'), null, jsonb '"med_document"');
  perform data.set_attribute_value(v_document_id, data.get_attribute_id('name'), null, to_jsonb(v_title));
  perform data.set_attribute_value(v_document_id, data.get_attribute_id('document_title'), null, to_jsonb(v_title));
  perform data.set_attribute_value(v_document_id, data.get_attribute_id('system_document_time'), null, to_jsonb(utils.system_time()));
  perform data.set_attribute_value(v_document_id, data.get_attribute_id('document_time'), null, to_jsonb(utils.current_time()));
  perform data.set_attribute_value(v_document_id, data.get_attribute_id('content'), null, to_jsonb(v_title));
  perform data.set_attribute_value(v_document_id, data.get_attribute_id('document_author'), null, to_jsonb(data.get_object_code(in_user_object_id)));
  perform data.set_attribute_value(v_document_id, data.get_attribute_id('med_document_patient'), null, to_jsonb(v_patient));

  return api_utils.get_objects(
    in_client,
    in_user_object_id,
    jsonb_build_object(
      'object_codes', jsonb_build_array(v_document_code),
      'get_actions', true,
      'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('create_med_document', null, 'Функция создания медецинского отчёта');

-- Действие для отправки письма
CREATE OR REPLACE FUNCTION action_generators.send_mail(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_type_attr_id integer;
  v_type text;
begin
  if v_object_id is not null then
    if v_object_id = v_user_object_id then
      return null;
    end if;

    v_type_attr_id := data.get_attribute_id('type');

    select json.get_string(value)
    into v_type
    from data.attribute_values
    where
      object_id = v_object_id and
      attribute_id = v_type_attr_id and
      value_object_id is null;

    if v_type != 'person' then
      return null;
    end if;
  end if;

  return jsonb_build_object(
    'send_mail',
    jsonb_build_object(
      'code', 'send_mail',
      'name', 'Написать письмо',
      'type', 'mail.send',
      'params', jsonb '{}',
      'user_params',
        jsonb_build_array(
          jsonb_build_object(
            'code', 'receivers',
            'type', 'objects',
            'data', jsonb_build_object('object_code', 'mail_contacts', 'attribute_code', 'mail_contacts'),
            'description', 'Получатели',
            'min_value_count', 1) ||
          case when v_object_id is null then
            jsonb '{}'
          else
            jsonb_build_object('default_value', data.get_object_code(v_object_id))
          end,
          jsonb_build_object(
            'code', 'title',
            'type', 'string',
            'data', jsonb_build_object('min_length', 1),
            'description', 'Тема',
            'min_value_count', 1,
            'max_value_count', 1),
          jsonb_build_object(
            'code', 'body',
            'type', 'string',
            'data', jsonb_build_object('min_length', 1, 'multiline', true),
            'description', 'Сообщение',
            'min_value_count', 1,
            'max_value_count', 1))));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.send_mail(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_receivers jsonb := in_user_params->'receivers';
  v_title text := json.get_string(in_user_params, 'title');
  v_body text := replace(json.get_string(in_user_params, 'body'), E'\n', '<br>');

  v_name_attr_id integer := data.get_attribute_id('name');
  v_type_attr_id integer := data.get_attribute_id('type');
  v_inbox_attr_id integer := data.get_attribute_id('inbox');
  v_outbox_attr_id integer := data.get_attribute_id('outbox');

  v_receiver_id integer;

  v_mail_id integer;
  v_mail_code text;
  v_mails jsonb;
begin
  assert jsonb_typeof(v_receivers) in ('array', 'string');

  insert into data.objects(id) values(default)
  returning id, code into v_mail_id, v_mail_code;

  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('system_is_visible'), null, jsonb 'true');
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('type'), null, jsonb '"mail"');
  perform data.set_attribute_value(v_mail_id, v_name_attr_id, null, to_jsonb(v_title));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_title'), null, to_jsonb(v_title));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('system_mail_send_time'), null, to_jsonb(utils.system_time()));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_send_time'), null, to_jsonb(utils.current_time()));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_author'), null, to_jsonb(data.get_object_code(in_user_object_id)));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_receivers'), null, jsonb '[]' || v_receivers);
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_body'), null, to_jsonb(v_body));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_type'), null, jsonb '"outbox"');

  v_mails := data.get_attribute_value_for_update(in_user_object_id, v_outbox_attr_id, in_user_object_id);

  perform data.set_attribute_value(in_user_object_id, v_outbox_attr_id, in_user_object_id, coalesce(v_mails, jsonb '[]') || to_jsonb(v_mail_code), in_user_object_id);

  insert into data.objects(id) values(default)
  returning id, code into v_mail_id, v_mail_code;

  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('system_is_visible'), null, jsonb 'true');
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('type'), null, jsonb '"mail"');
  perform data.set_attribute_value(v_mail_id, v_name_attr_id, null, to_jsonb(v_title));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_title'), null, to_jsonb(v_title));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('system_mail_send_time'), null, to_jsonb(utils.system_time()));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_send_time'), null, to_jsonb(utils.current_time()));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_author'), null, to_jsonb(data.get_object_code(in_user_object_id)));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_receivers'), null, jsonb '[]' || v_receivers);
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_body'), null, to_jsonb(v_body));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_type'), null, jsonb '"inbox"');

  for v_receiver_id in
    select distinct(av.object_id)
    from jsonb_array_elements(jsonb '[]' || v_receivers) r
    join data.objects o on
      o.code = json.get_string(r.value)
    join data.object_objects oo on
      oo.parent_object_id = o.id
    join data.attribute_values av on
      av.object_id = oo.object_id and
      av.attribute_id = v_type_attr_id and
      av.value_object_id is null and
      av.value = jsonb '"person"'
  loop
    v_mails := data.get_attribute_value_for_update(v_receiver_id, v_inbox_attr_id, v_receiver_id);
    perform data.set_attribute_value(v_receiver_id, v_inbox_attr_id, v_receiver_id, coalesce(v_mails, jsonb '[]') || to_jsonb(v_mail_code), in_user_object_id);
    perform actions.create_notification(
      in_user_object_id,
      array[v_receiver_id],
      'Новое письмо. Отправитель: ' || json.get_string(data.get_attribute_value(v_receiver_id, in_user_object_id, v_name_attr_id)) || '. Тема: ' || v_title,
      v_mail_code);
  end loop;

  return api_utils.create_ok_result(null, 'Сообщение отправлено!');
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_user_attribute', jsonb_build_object('attribute_code', 'type', 'attribute_value', 'person', 'function', 'send_mail'), 'Функция отправки письма');

CREATE OR REPLACE FUNCTION action_generators.reply(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_user_object_id integer;
  v_mail_author_attr_id integer;
  v_title_attr_id integer;
  v_body_attr_id integer;
  v_author text;
  v_title text;
  v_body text;
begin
  if v_object_id is null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
  v_mail_author_attr_id := data.get_attribute_id('mail_author');
  v_title_attr_id := data.get_attribute_id('mail_title');
  v_body_attr_id := data.get_attribute_id('mail_body');

  select json.get_string(value)
  into v_author
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_mail_author_attr_id and
    value_object_id is null;

  select json.get_string(value)
  into v_body
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_body_attr_id and
    value_object_id is null;

  select json.get_string(value)
  into v_title
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_title_attr_id and
    value_object_id is null;

  return jsonb_build_object(
    'reply',
    jsonb_build_object(
      'code', 'send_mail',
      'name', 'Ответить',
      'type', 'mail.reply',
      'params', jsonb '{}',
      'user_params',
        jsonb_build_array(
          jsonb_build_object(
            'code', 'receivers',
            'type', 'objects',
            'data', jsonb_build_object('object_code', 'mail_contacts', 'attribute_code', 'mail_contacts'),
            'description', 'Получатели',
            'default_value', v_author,
            'min_value_count', 1),
          jsonb_build_object(
            'code', 'title',
            'type', 'string',
            'data', jsonb_build_object('min_length', 1),
            'description', 'Тема',
            'default_value', 'Re: ' || v_title,
            'min_value_count', 1,
            'max_value_count', 1),
          jsonb_build_object(
            'code', 'body',
            'type', 'string',
            'data', jsonb_build_object('min_length', 1, 'multiline', true),
            'description', 'Сообщение',
            'default_value', E'\n> ' || replace(v_title, '<br>', '\n> '),
            'min_value_count', 1,
            'max_value_count', 1))));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_attribute', jsonb_build_object('attribute_code', 'type', 'attribute_value', 'mail', 'function', 'reply'), 'Функция ответа на письмо');

CREATE OR REPLACE FUNCTION action_generators.reply_all(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_user_object_id integer;
  v_mail_author_attr_id integer;
  v_mail_receivers_attr_id integer;
  v_title_attr_id integer;
  v_body_attr_id integer;
  v_author jsonb;
  v_receivers jsonb;
  v_title text;
  v_body text;
begin
  if v_object_id is null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
  v_mail_author_attr_id := data.get_attribute_id('mail_author');
  v_mail_receivers_attr_id := data.get_attribute_id('mail_receivers');
  v_title_attr_id := data.get_attribute_id('mail_title');
  v_body_attr_id := data.get_attribute_id('mail_body');

  select value
  into v_author
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_mail_author_attr_id and
    value_object_id is null;

  perform json.get_string(v_author);

  select value
  into v_receivers
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_mail_receivers_attr_id and
    value_object_id is null;

  perform json.get_string_array(v_receivers);

  select json.get_string(value)
  into v_body
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_body_attr_id and
    value_object_id is null;

  select json.get_string(value)
  into v_title
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_title_attr_id and
    value_object_id is null;

  return jsonb_build_object(
    'reply_all',
    jsonb_build_object(
      'code', 'send_mail',
      'name', 'Ответить всем',
      'type', 'mail.reply_all',
      'params', jsonb '{}',
      'user_params',
        jsonb_build_array(
          jsonb_build_object(
            'code', 'receivers',
            'type', 'objects',
            'data', jsonb_build_object('object_code', 'mail_contacts', 'attribute_code', 'mail_contacts'),
            'description', 'Получатели',
            'default_value', v_author || (v_receivers - json.get_string(v_author)),
            'min_value_count', 1),
          jsonb_build_object(
            'code', 'title',
            'type', 'string',
            'data', jsonb_build_object('min_length', 1),
            'description', 'Тема',
            'default_value', 'Re: ' || v_title,
            'min_value_count', 1,
            'max_value_count', 1),
          jsonb_build_object(
            'code', 'body',
            'type', 'string',
            'data', jsonb_build_object('min_length', 1, 'multiline', true),
            'description', 'Сообщение',
            'default_value', E'\n> ' || replace(v_title, '<br>', '\n> '),
            'min_value_count', 1,
            'max_value_count', 1))));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_attribute', jsonb_build_object('attribute_code', 'type', 'attribute_value', 'mail', 'function', 'reply_all'), 'Функция ответа на письмо всем отправителям');

-- Отправка писем из будущего
CREATE OR REPLACE FUNCTION action_generators.send_mail_from_future(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_type_attr_id integer;
  v_type text;
  v_user_object_id integer;
begin
  if v_object_id is not null then
    v_type_attr_id := data.get_attribute_id('type');

    select json.get_string(value)
    into v_type
    from data.attribute_values
    where
      object_id = v_object_id and
      attribute_id = v_type_attr_id and
      value_object_id is null;

    if v_type != 'person' then
      return null;
    end if;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
  
  return jsonb_build_object(
    'send_mail_from_future',
    jsonb_build_object(
      'code', 'send_mail_from_future',
      'name', 'Написать письмо из будущего',
      'type', 'cheats.mail.send_from_future',
      'params', jsonb '{}',
      'user_params',
        jsonb_build_array(
          jsonb_build_object(
            'code', 'author',
            'type', 'objects',
            'data', jsonb_build_object('object_code', 'mail_contacts', 'attribute_code', 'mail_contacts'),
            'description', 'Отправитель',
            'min_value_count', 1,
            'max_value_count', 1) ||
          case when v_object_id is null then
            jsonb '{}'
          else
            jsonb_build_object('default_value', data.get_object_code(v_object_id))
          end,
          jsonb_build_object(
            'code', 'receivers',
            'type', 'objects',
            'data', jsonb_build_object('object_code', 'mail_contacts', 'attribute_code', 'mail_contacts'),
            'description', 'Получатели',
            'min_value_count', 1) ||
          case when v_object_id is null then
            jsonb '{}'
          else
            jsonb_build_object('default_value', data.get_object_code(v_object_id))
          end,
          jsonb_build_object(
            'code', 'title',
            'type', 'string',
            'data', jsonb_build_object('min_length', 1),
            'description', 'Тема',
            'min_value_count', 1,
            'max_value_count', 1),
          jsonb_build_object(
            'code', 'days',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 1),
            'description', 'Через сколько дней будет отправлено письмо?',
            'min_value_count', 1,
            'max_value_count', 1),
          jsonb_build_object(
            'code', 'body',
            'type', 'string',
            'data', jsonb_build_object('min_length', 1, 'multiline', true),
            'description', 'Сообщение',
            'min_value_count', 1,
            'max_value_count', 1))));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.send_mail_from_future(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_author jsonb := in_user_params->'author';
  v_author_id integer := data.get_object_id(json.get_string(v_author));
  v_receivers jsonb := in_user_params->'receivers';
  v_title text := json.get_string(in_user_params, 'title');
  v_body text := replace(json.get_string(in_user_params, 'body'), E'\n', '<br>');
  v_days integer := json.get_integer(in_user_params, 'days');

  v_name_attr_id integer := data.get_attribute_id('name');
  v_type_attr_id integer := data.get_attribute_id('type');
  v_inbox_attr_id integer := data.get_attribute_id('inbox');

  v_receiver_id integer;

  v_mail_id integer;
  v_mail_code text;
  v_mails jsonb;
begin
  assert jsonb_typeof(v_receivers) in ('array', 'string');
  perform json.get_string(v_author);

  insert into data.objects(id) values(default)
  returning id, code into v_mail_id, v_mail_code;

  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('system_is_visible'), null, jsonb 'true');
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('type'), null, jsonb '"mail"');
  perform data.set_attribute_value(v_mail_id, v_name_attr_id, null, to_jsonb(v_title));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_title'), null, to_jsonb(v_title));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('system_mail_send_time'), null, to_jsonb(utils.system_time(v_days)));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_send_time'), null, to_jsonb(utils.current_time(v_days)));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_author'), null, v_author);
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_receivers'), null, jsonb '[]' || v_receivers);
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_body'), null, to_jsonb(v_body));
  perform data.set_attribute_value(v_mail_id, data.get_attribute_id('mail_type'), null, jsonb '"inbox"');

  for v_receiver_id in
    select distinct(av.object_id)
    from jsonb_array_elements(jsonb '[]' || v_receivers) r
    join data.objects o on
      o.code = json.get_string(r.value)
    join data.object_objects oo on
      oo.parent_object_id = o.id
    join data.attribute_values av on
      av.object_id = oo.object_id and
      av.attribute_id = v_type_attr_id and
      av.value_object_id is null and
      av.value = jsonb '"person"'
  loop
    v_mails := data.get_attribute_value_for_update(v_receiver_id, v_inbox_attr_id, v_receiver_id);
    perform data.set_attribute_value(v_receiver_id, v_inbox_attr_id, v_receiver_id, coalesce(v_mails, jsonb '[]') || to_jsonb(v_mail_code), in_user_object_id);
    perform actions.create_notification(
      in_user_object_id,
      array[v_receiver_id],
      'Новое письмо. Отправитель: ' || json.get_string(data.get_attribute_value(v_receiver_id, v_author_id, v_name_attr_id)) || '. Тема: ' || v_title,
      v_mail_code,
      v_days);
  end loop;

  return api_utils.create_ok_result(null, 'Сообщение отправлено!');
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_user_attribute', jsonb_build_object('attribute_code', 'system_master', 'attribute_value', true, 'function', 'send_mail_from_future'), 'Функция отправки письма из будущего');

-- Удаление писем
CREATE OR REPLACE FUNCTION action_generators.delete_outbox_mail(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');

  v_user_object_id integer;
  v_mail_author_attr_id integer;

  v_person_id integer;

  v_outbox_attr_id integer;

  v_value jsonb;
  v_mail_code text;
begin
  if v_object_id is null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
  v_mail_author_attr_id := data.get_attribute_id('mail_author');

  select data.get_object_id(json.get_string(value))
  into v_person_id
  from data.attribute_values
  where
    object_id = v_object_id and
    attribute_id = v_mail_author_attr_id and
    value_object_id is null;

  if v_person_id != v_user_object_id then
    return null;
  end if;

  v_outbox_attr_id := data.get_attribute_id('outbox');

  select value
  into v_value
  from data.attribute_values
  where
    object_id = v_user_object_id and
    attribute_id = v_outbox_attr_id and
    value_object_id = v_user_object_id;

  if v_value is null then
    return null;
  end if;

  perform json.get_string_array(v_value);

  v_mail_code := data.get_object_code(v_object_id);

  if not v_value ? v_mail_code then
    return null;
  end if;

  return jsonb_build_object(
    'delete_mail',
    jsonb_build_object(
      'code', 'delete_outbox_mail',
      'name', 'Удалить',
      'type', 'mail.delete',
      'params', jsonb_build_object('mail_code', v_mail_code),
      'warning', 'Вы действительно хотите удалить письмо?'));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.delete_outbox_mail(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_mail_code text := json.get_string(in_params, 'mail_code');
  v_outbox_attr_id integer := data.get_attribute_id('outbox');
  v_value jsonb;
begin
  v_value := data.get_attribute_value_for_update(in_user_object_id, v_outbox_attr_id, in_user_object_id);
  if v_value is not null and v_value ? v_mail_code then
    v_value := v_value - v_mail_code;
    if jsonb_array_length(v_value) = 0 then
      perform data.delete_attribute_value(in_user_object_id, v_outbox_attr_id, in_user_object_id);
    else
      perform data.set_attribute_value(in_user_object_id, v_outbox_attr_id, in_user_object_id, v_value, in_user_object_id);
    end if;
  end if;

  return api_utils.get_objects(
    in_client,
    in_user_object_id,
    jsonb_build_object(
      'object_codes', jsonb '["mailbox"]',
      'get_actions', true,
      'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values(
  'generate_if_attribute',
  jsonb_build_object('attribute_code', 'mail_type', 'attribute_value', 'outbox', 'function', 'delete_outbox_mail'),
  'Функция удаления исходящего письма');

CREATE OR REPLACE FUNCTION action_generators.delete_inbox_mail(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');

  v_user_object_id integer;

  v_inbox_attr_id integer;

  v_value jsonb;
  v_mail_code text;
begin
  if v_object_id is null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');

  v_inbox_attr_id := data.get_attribute_id('inbox');

  select value
  into v_value
  from data.attribute_values
  where
    object_id = v_user_object_id and
    attribute_id = v_inbox_attr_id and
    value_object_id = v_user_object_id;

  if v_value is null then
    return null;
  end if;

  perform json.get_string_array(v_value);

  v_mail_code := data.get_object_code(v_object_id);

  if not v_value ? v_mail_code then
    return null;
  end if;

  return jsonb_build_object(
    'delete_mail',
    jsonb_build_object(
      'code', 'delete_inbox_mail',
      'name', 'Удалить',
      'type', 'mail.delete',
      'params', jsonb_build_object('mail_code', v_mail_code),
      'warning', 'Вы действительно хотите удалить письмо?'));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.delete_inbox_mail(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_mail_code text := json.get_string(in_params, 'mail_code');
  v_inbox_attr_id integer := data.get_attribute_id('inbox');
  v_value jsonb;
begin
  v_value := data.get_attribute_value_for_update(in_user_object_id, v_inbox_attr_id, in_user_object_id);
  if v_value is not null and v_value ? v_mail_code then
    v_value := v_value - v_mail_code;
    if jsonb_array_length(v_value) = 0 then
      perform data.delete_attribute_value(in_user_object_id, v_inbox_attr_id, in_user_object_id);
    else
      perform data.set_attribute_value(in_user_object_id, v_inbox_attr_id, in_user_object_id, v_value, in_user_object_id);
    end if;
  end if;

  return api_utils.get_objects(
    in_client,
    in_user_object_id,
    jsonb_build_object(
      'object_codes', jsonb '["mailbox"]',
      'get_actions', true,
      'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values(
  'generate_if_attribute',
  jsonb_build_object('attribute_code', 'mail_type', 'attribute_value', 'inbox', 'function', 'delete_inbox_mail'),
  'Функция удаления входящего письма');

-- Действие для изменения процента налога для страны
CREATE OR REPLACE FUNCTION action_generators.change_state_tax(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
begin
  return jsonb_build_object(
    'change_state_tax',
    jsonb_build_object(
      'code', 'change_state_tax',
      'name', 'Изменить процентную ставку налога',
      'type', 'financial.tax.change',
      'params', jsonb_build_object('state_code', data.get_object_code(json.get_integer(in_params, 'object_id'))),
      'user_params', 
        jsonb_build_array(
          jsonb_build_object(
            'code', 'tax',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 100),
            'description', 'Процентная ставка',
            'default_value', data.get_attribute_value(json.get_integer(in_params, 'user_object_id'),json.get_integer(in_params, 'object_id'), data.get_attribute_id('state_tax')),
            'min_value_count', 1,
            'max_value_count', 1))));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.change_state_tax(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_state_code text := json.get_string(in_params, 'state_code');
  v_state_id integer := data.get_object_id(v_state_code);
  v_state_tax_attribute_id integer := data.get_attribute_id('state_tax');
  v_tax integer := json.get_integer(in_user_params, 'tax');
begin
  perform data.set_attribute_value_if_changed(
    v_state_id,
    v_state_tax_attribute_id,
    null,
    v_tax::text::jsonb,
    in_user_object_id);

  return api_utils.get_objects(in_client,
			  in_user_object_id,
			  jsonb_build_object(
			    'object_codes', jsonb_build_array(v_state_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_attribute', jsonb_build_object('attribute_code', 'type', 'attribute_value', 'state', 'function', 'change_state_tax'), 'Функция для изменения процента налога для страны');

-- Действие для голосования за выплату дивидендов
CREATE OR REPLACE FUNCTION action_generators.set_dividend_vote(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_is_in_group integer; 
begin
  select count(1) into v_is_in_group 
  from data.object_objects oo
   where oo.parent_object_id = json.get_integer(in_params, 'object_id')
   and oo.object_id = json.get_opt_integer(in_params, null, 'user_object_id');

  if v_is_in_group = 0 or json.get_opt_string(data.get_attribute_value(json.get_integer(in_params, 'user_object_id'),
								       json.get_integer(in_params, 'object_id'), 
								       data.get_attribute_id('dividend_vote'))) = 'Да' then
    return null;
  end if;
  
  return jsonb_build_object(
    'set_dividend_vote',
    jsonb_build_object(
      'code', 'set_dividend_vote',
      'name', 'Проголосовать за выплату дивидендов',
      'type', 'vote.dividend',
      'warning', 'Вы уверены, что хотите проголосовать за выплату дивидендов? Это решение нельзя будет изменить до конца цикла.',
      'params', jsonb_build_object('corporation_code', data.get_object_code(json.get_integer(in_params, 'object_id')))));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.set_dividend_vote(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_corporation_code text := json.get_string(in_params, 'corporation_code');
  v_corporation_id integer := data.get_object_id(v_corporation_code);
  v_dividend_vote_attribute_id integer := data.get_attribute_id('dividend_vote');
begin
  perform data.set_attribute_value_if_changed(
    v_corporation_id,
    v_dividend_vote_attribute_id,
    in_user_object_id,
    jsonb '"Да"',
    in_user_object_id);

  return api_utils.get_objects(in_client,
			  in_user_object_id,
			  jsonb_build_object(
			    'object_codes', jsonb_build_array(v_corporation_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_attribute', jsonb_build_object('attribute_code', 'type', 'attribute_value', 'corporation', 'function', 'set_dividend_vote'), 'Функция для голосование за выплату дивидендов');

-- Действие для создания сделки
CREATE OR REPLACE FUNCTION action_generators.create_deal(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_is_in_group integer; 
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
begin
  select count(1) into v_is_in_group 
  from data.object_objects oo
   where oo.parent_object_id = json.get_integer(in_params, 'object_id')
   and oo.object_id = v_user_object_id;

  if v_is_in_group = 0 and
    not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_master')), false) then
    return null;
  end if;
  
  return jsonb_build_object(
    'create_deal',
    jsonb_build_object(
      'code', 'create_deal',
      'name', 'Создать сделку',
      'type', 'financial.deal',
      'params', jsonb_build_object('corporation_code', data.get_object_code(json.get_integer(in_params, 'object_id'))),
      'user_params', 
       jsonb_build_array(
         jsonb_build_object(
            'code', 'deal_name',
            'type', 'string',
            'description', 'Название сделки',
             'data', jsonb_build_object('min_length', 1),
            'min_value_count', 1,
            'max_value_count', 1),
         jsonb_build_object(
            'code', 'description',
            'type', 'string',
            'description', 'Описание сделки',
            'data', jsonb_build_object('min_length', 1, 'multiline', true),
            'min_value_count', 1,
            'max_value_count', 1),
         jsonb_build_object(
            'code', 'deal_sector',
            'type', 'objects',
            'description', 'Рынок сделки',
            'data', jsonb_build_object('object_code', 'market', 'attribute_code', 'sectors'),
            'min_value_count', 1,
            'max_value_count', 1),
         jsonb_build_object(
            'code', 'asset_name',
            'type', 'string',
            'description', 'Название актива',
            'data', jsonb_build_object('min_length', 1),
            'min_value_count', 1,
            'max_value_count', 1),
         jsonb_build_object(
            'code', 'deal_income',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 1000000000000),
            'description', 'Доходность сделки',
            'min_value_count', 1,
            'max_value_count', 1),
        jsonb_build_object(
            'code', 'percent_asset',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 100),
            'description', '% владения активом для вашей корпорации',
            'min_value_count', 1,
            'max_value_count', 1),
        jsonb_build_object(
            'code', 'percent_income',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 100),
            'description', '% дохода от сделки для вашей корпорации',
            'min_value_count', 1,
            'max_value_count', 1),
        jsonb_build_object(
            'code', 'deal_cost',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 100000000000),
            'description', 'Вложения в сделку для вашей корпорации',
            'min_value_count', 1,
            'max_value_count', 1)))
      );
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.create_deal(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_corporation_code text := json.get_string(in_params, 'corporation_code');
  v_corporation_id integer := data.get_object_id(v_corporation_code);
  v_deal_id integer;
  v_deal_code text;
  v_deal_name text := json.get_string(in_user_params, 'deal_name');
  v_description text := json.get_string(in_user_params, 'description');
  v_asset_name text := json.get_string(in_user_params, 'asset_name');
  v_deal_income integer := json.get_integer(in_user_params, 'deal_income');
  v_deal_sector text := json.get_string(in_user_params, 'deal_sector');
  v_percent_asset integer := json.get_integer(in_user_params, 'percent_asset');
  v_percent_income integer := json.get_integer(in_user_params, 'percent_income');
  v_deal_cost integer := json.get_integer(in_user_params, 'deal_cost');

  v_system_corporation_draft_deals_attribute_id integer := data.get_attribute_id('system_corporation_draft_deals');
  v_value jsonb;
begin
insert into data.objects(id) values(default)
  returning id, code into v_deal_id, v_deal_code;

  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('system_is_visible'), null, jsonb 'true', in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('type'), null, jsonb '"deal"', in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('name'), null, to_jsonb(v_deal_name), in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('deal_author'), null, to_jsonb(in_user_object_id), in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('description'), null, to_jsonb(v_description), in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('deal_sector'), null, to_jsonb(v_deal_sector), in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('asset_name'), null, to_jsonb(v_asset_name), in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('deal_income'), null, to_jsonb(v_deal_income), in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('system_deal_time'), null, to_jsonb(utils.system_time()), in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('deal_status'), null, jsonb '"draft"', in_user_object_id, in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('asset_cost'), null, to_jsonb(round(v_deal_cost * 0.7)), in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('asset_amortization'), null, to_jsonb(round(v_deal_cost * 0.07)), in_user_object_id);
  perform data.set_attribute_value(v_deal_id, data.get_attribute_id('system_deal_participant1'), null, ('{"member" : "' || v_corporation_code || '","percent_asset" : ' || v_percent_asset || ', "percent_income" : ' || v_percent_income || ', "deal_cost": ' || v_deal_cost || '}')::jsonb, in_user_object_id);

-- Вставим сделку в подготавливаемые для этой корпорации
    v_value := json.get_opt_array(
        data.get_attribute_value_for_update(
          v_corporation_id,
          v_system_corporation_draft_deals_attribute_id,
          null));
    v_value := coalesce(v_value, jsonb '[]') || jsonb_build_array(v_deal_code);
    perform data.set_attribute_value(v_corporation_id, v_system_corporation_draft_deals_attribute_id, null, v_value, in_user_object_id);

  return api_utils.get_objects(in_client,
			  in_user_object_id,
			  jsonb_build_object(
			    'object_codes', jsonb_build_array(v_deal_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_attribute', jsonb_build_object('attribute_code', 'type', 'attribute_value', 'corporation', 'function', 'create_deal'), 'Функция для добавления сделки');

-- Действие для добавления участника сделки
CREATE OR REPLACE FUNCTION action_generators.add_deal_member(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_i integer;
  v_j integer;
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  
begin
 -- Показываем только для автора сделки или мастера, и если она ещё черновик
  if json.get_opt_integer(data.get_attribute_value(v_user_object_id,
					       v_object_id, 
					       data.get_attribute_id('deal_author')),0) <> v_user_object_id and
    not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_master')), false)  or 
     json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('deal_status')),'~') <> 'draft' then
    return null;
  end if;

  -- Проверка, что остались свободные ячейки под участников сделки
  for v_i in 1..10 loop
    if data.get_attribute_value(v_user_object_id, v_object_id, data.get_attribute_id('system_deal_participant' || v_i)) is null then
      v_j := v_i;
      exit;
    end if;
  end loop;
  
  if v_j is null then
    return null;
  end if;
  
  return jsonb_build_object(
    'add_deal_member',
    jsonb_build_object(
      'code', 'add_deal_member',
      'name', 'Добавить участника сделки',
      'type', 'financial.deal',
      'params', jsonb_build_object('deal_code', data.get_object_code(json.get_integer(in_params, 'object_id'))),
      'user_params', 
       jsonb_build_array(
         jsonb_build_object(
            'code', 'member',
            'type', 'objects',
            'description', 'Добавляемый участник',
            'data', jsonb_build_object('object_code', 'corporations', 'attribute_code', 'corporations'),
            'min_value_count', 1,
            'max_value_count', 1),
        jsonb_build_object(
            'code', 'percent_asset',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 100),
            'description', '% владения активом',
            'min_value_count', 1,
            'max_value_count', 1),
        jsonb_build_object(
            'code', 'percent_income',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 100),
            'description', '% дохода от сделки',
            'min_value_count', 1,
            'max_value_count', 1),
        jsonb_build_object(
            'code', 'deal_cost',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 100000000000),
            'description', 'Вложения в сделку',
            'min_value_count', 1,
            'max_value_count', 1)))
      );
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.add_deal_member(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_deal_code text := json.get_string(in_params, 'deal_code');
  v_deal_id integer := data.get_object_id(v_deal_code);
  v_member text := json.get_string(in_user_params, 'member');
  v_corporation_id integer := data.get_object_id(v_member);
  v_percent_asset integer := json.get_integer(in_user_params, 'percent_asset');
  v_percent_income integer := json.get_integer(in_user_params, 'percent_income');
  v_deal_cost integer := json.get_integer(in_user_params, 'deal_cost');

  v_i integer;
  v_j integer;

  v_system_corporation_draft_deals_attribute_id integer := data.get_attribute_id('system_corporation_draft_deals');
  v_value jsonb;
  v_sum_percent_asset integer := 0;
  v_sum_percent_income integer := 0;
  v_sum_deal_cost integer := 0;
  v_curent_member text;
  v_ret_val api.result;
begin
  v_ret_val := api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_deal_code),
			    'get_actions', true,
			    'get_templates', true));
  if json.get_opt_string(data.get_attribute_value(in_user_object_id,
					          v_deal_id, 
					          data.get_attribute_id('deal_status')),'~') <> 'draft' then
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Статус сделки изменился!"}';
    return v_ret_val;
   end if;
  for v_i in 1..10 loop
    v_value := data.get_attribute_value(in_user_object_id, v_deal_id, data.get_attribute_id('system_deal_participant' || v_i));
    if v_j is null and v_value is null then
      v_j := v_i;
    end if;
    if v_value is not null then
      select c.member,
             v_sum_percent_asset + coalesce(c.percent_asset, 0),
             v_sum_percent_income + coalesce(c.percent_income, 0),
             v_sum_deal_cost + coalesce(c.deal_cost, 0)
      into v_curent_member,
           v_sum_percent_asset,
           v_sum_percent_income,
           v_sum_deal_cost
      from jsonb_to_record(v_value) as c (member text, percent_asset int, percent_income int, deal_cost int);
      if v_curent_member = v_member then
        v_ret_val.data := v_ret_val.data || jsonb '{"message": "Эта корпорация уже участвует в данной сделке!"}';
    return v_ret_val;
      end if;
    end if;    
  end loop;

  if v_j is null then
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Достигнуто максимальное количество участников сделки!"}';
    return v_ret_val;
  elsif v_sum_percent_asset + v_percent_asset > 100 then
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Сумарный процент владения активом превысил 100!"}';
    return v_ret_val;
  elsif v_sum_percent_income + v_percent_income > 100 then
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Сумарный процент распределения доходов сделки превысил 100!"}';
    return v_ret_val;
  end if;

  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('asset_cost'), null, to_jsonb(round((v_sum_deal_cost + v_deal_cost) * 0.7)), in_user_object_id);
  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('asset_amortization'), null, to_jsonb(round((v_sum_deal_cost + v_deal_cost) * 0.07)), in_user_object_id);
  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('system_deal_participant' || v_j), null, ('{"member" : "' || v_member || '","percent_asset" : ' || v_percent_asset || ', "percent_income" : ' || v_percent_income || ', "deal_cost": ' || v_deal_cost || '}')::jsonb, in_user_object_id);

  -- Вставим сделку в подготавливаемые для этой корпорации
  v_value := json.get_opt_array(
        data.get_attribute_value_for_update(
          v_corporation_id,
          v_system_corporation_draft_deals_attribute_id,
          null));
  v_value := coalesce(v_value, jsonb '[]') || jsonb_build_array(v_deal_code);
  perform data.set_attribute_value(v_corporation_id, v_system_corporation_draft_deals_attribute_id, null, v_value, in_user_object_id);


  return api_utils.get_objects(in_client,
			  in_user_object_id,
			  jsonb_build_object(
			    'object_codes', jsonb_build_array(v_deal_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_attribute', jsonb_build_object('attribute_code', 'type', 'attribute_value', 'deal', 'function', 'add_deal_member'), 'Функция для добавления участника сделки');

-- Действие для изменения участника сделки 
CREATE OR REPLACE FUNCTION action_generators.edit_deal_member(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_row_num integer := json.get_integer(in_params, 'row_num');
  v_value jsonb;
  v_member text;
begin
  -- Показываем, если соответствующий участник уже добавлен
  v_value := data.get_attribute_value(v_user_object_id,
				       v_object_id, 
			               data.get_attribute_id('system_deal_participant' || v_row_num));
  if v_value is null then
    return null;
  else
   v_member := json.get_opt_string(v_value -> 'member');
  end if;
 -- Показываем только для автора сделки или мастера, и если она ещё черновик 
  if json.get_opt_integer(data.get_attribute_value(v_user_object_id,
					       v_object_id, 
					       data.get_attribute_id('deal_author')), 0) <> v_user_object_id and
    not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_master')), false) or 
     json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('deal_status')),'~') <> 'draft' or
     v_member is null then
    return null;
  end if;

  return jsonb_build_object(
    'edit_deal_member' || v_row_num,
    jsonb_build_object(
      'code', 'edit_deal_member',
      'name', 'Изменить параметры участника сделки',
      'type', 'financial.deal',
      'params', jsonb_build_object('deal_code', data.get_object_code(v_object_id), 'corporation_code' , v_member),
      'user_params', 
       jsonb_build_array(
        jsonb_build_object(
            'code', 'percent_asset',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 100),
            'description', '% владения активом',
            'default_value', json.get_opt_integer(v_value -> 'percent_asset'),
            'min_value_count', 1,
            'max_value_count', 1),
        jsonb_build_object(
            'code', 'percent_income',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 100),
            'description', '% дохода от сделки',
             'default_value', json.get_opt_integer(v_value -> 'percent_income'),
            'min_value_count', 1,
            'max_value_count', 1),
        jsonb_build_object(
            'code', 'deal_cost',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 100000000000),
            'description', 'Вложения в сделку',
            'default_value', json.get_opt_integer(v_value -> 'deal_cost'),
            'min_value_count', 1,
            'max_value_count', 1)))
      );
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.edit_deal_member(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_deal_code text := json.get_string(in_params, 'deal_code');
  v_deal_id integer := data.get_object_id(v_deal_code);
  v_member text := json.get_string(in_params, 'corporation_code');
  v_corporation_id integer := data.get_object_id(v_member);
  v_percent_asset integer := json.get_integer(in_user_params, 'percent_asset');
  v_percent_income integer := json.get_integer(in_user_params, 'percent_income');
  v_deal_cost integer := json.get_integer(in_user_params, 'deal_cost');

  v_i integer;
  v_j integer;

  v_value jsonb;
  v_sum_percent_asset integer := 0;
  v_sum_percent_income integer := 0;
  v_sum_deal_cost integer := 0;
  v_curent_member text;
  v_ret_val api.result;
begin
  v_ret_val := api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_deal_code),
			    'get_actions', true,
			    'get_templates', true));
  if json.get_opt_string(data.get_attribute_value(in_user_object_id,
					          v_deal_id, 
					          data.get_attribute_id('deal_status')),'~') <> 'draft' then
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Статус сделки изменился!"}';
    return v_ret_val;
  end if;
  for v_i in 1..10 loop
    v_value := data.get_attribute_value(in_user_object_id, v_deal_id, data.get_attribute_id('system_deal_participant' || v_i));
    if v_value is not null then
      if json.get_opt_string(v_value -> 'member') = v_member then
        v_j := v_i;
      else
        select v_sum_percent_asset + coalesce(c.percent_asset, 0),
               v_sum_percent_income + coalesce(c.percent_income, 0),
               v_sum_deal_cost + coalesce(c.deal_cost, 0)
        into v_sum_percent_asset,
             v_sum_percent_income,
             v_sum_deal_cost
        from jsonb_to_record(v_value) as c (percent_asset int, percent_income int, deal_cost int);
      end if;
    end if;    
  end loop;

  if v_sum_percent_asset + v_percent_asset > 100 then
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Сумарный процент владения активом превысил 100!"}';
    return v_ret_val;
  elsif v_sum_percent_income + v_percent_income > 100 then
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Сумарный процент распределения доходов сделки превысил 100!"}';
    return v_ret_val;
  end if;

  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('asset_cost'), null, to_jsonb(round((v_sum_deal_cost + v_deal_cost) * 0.7)), in_user_object_id);
  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('asset_amortization'), null, to_jsonb(round((v_sum_deal_cost + v_deal_cost) * 0.07)), in_user_object_id);
  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('system_deal_participant' || v_j), null, ('{"member" : "' || v_member || '","percent_asset" : ' || v_percent_asset || ', "percent_income" : ' || v_percent_income || ', "deal_cost": ' || v_deal_cost || '}')::jsonb, in_user_object_id);

  return api_utils.get_objects(in_client,
			  in_user_object_id,
			  jsonb_build_object(
			    'object_codes', jsonb_build_array(v_deal_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
select
  'generate_if_attribute', 
  jsonb_build_object('attribute_code', 
		     'type', 
		     'attribute_value', 
		     'deal', 
		     'function', 
		     'edit_deal_member', 
		     'params',
		     jsonb_build_object('row_num', o.value)), 
  'Функция для изменения участника сделки'
 from generate_series(1, 10) o(value);

 -- Действие для удаления участника сделки 
CREATE OR REPLACE FUNCTION action_generators.delete_deal_member(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_row_num integer := json.get_integer(in_params, 'row_num');
  v_value jsonb;
  v_member text;
begin
  -- Показываем, если соответствующий участник уже добавлен
  v_value := data.get_attribute_value(v_user_object_id,
				       v_object_id, 
			               data.get_attribute_id('system_deal_participant' || v_row_num));
  if v_value is null then
    return null;
  else
   v_member := json.get_opt_string(v_value -> 'member');
  end if;
 -- Показываем только для автора сделки или мастера, и если она ещё черновик 
  if json.get_opt_integer(data.get_attribute_value(v_user_object_id,
					       v_object_id, 
					       data.get_attribute_id('deal_author')),0) <> v_user_object_id and
    not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_master')), false) or 
     json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('deal_status')),'~') <> 'draft' or
     v_member is null then
    return null;
  end if;

  return jsonb_build_object(
    'delete_deal_member' || v_row_num,
    jsonb_build_object(
      'code', 'delete_deal_member',
      'name', 'Удалить участника сделки',
      'type', 'financial.deal',
      'warning', 'Вы действительно хотите удалить ' || json.get_string(data.get_attribute_value(v_user_object_id, data.get_object_id(v_member), data.get_attribute_id('name'))) || ' из участников сделки?',
      'params', jsonb_build_object('deal_code', data.get_object_code(v_object_id), 'corporation_code' , v_member))
      );
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.delete_deal_member(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_deal_code text := json.get_string(in_params, 'deal_code');
  v_deal_id integer := data.get_object_id(v_deal_code);
  v_member text := json.get_string(in_params, 'corporation_code');
  v_corporation_id integer := data.get_object_id(v_member);

  v_i integer;
  v_j integer := 1;

  v_value jsonb;
  v_sum_deal_cost integer := 0;
  v_system_corporation_draft_deals_attribute_id integer := data.get_attribute_id('system_corporation_draft_deals');
  v_ret_val api.result;
begin
  v_ret_val := api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_deal_code),
			    'get_actions', true,
			    'get_templates', true));
  if json.get_opt_string(data.get_attribute_value(in_user_object_id,
					          v_deal_id, 
					          data.get_attribute_id('deal_status')),'~') <> 'draft' then
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Статус сделки изменился!"}';
    return v_ret_val;
   end if;
  for v_i in 1..10 loop
    v_value := data.get_attribute_value(in_user_object_id, v_deal_id, data.get_attribute_id('system_deal_participant' || v_i));
    if v_value is not null then
      if json.get_opt_string(v_value -> 'member') = v_member then
        v_j := v_j - 1;
      else
        if v_j < v_i then
          perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('system_deal_participant' || v_j), null, v_value, in_user_object_id);
        end if;
        v_sum_deal_cost := v_sum_deal_cost + json.get_opt_integer(v_value -> 'deal_cost', 0);
      end if;
    elsif v_j < v_i then
      perform data.delete_attribute_value_if_exists(v_deal_id, data.get_attribute_id('system_deal_participant' || v_j), null, in_user_object_id);
    end if; 
    v_j := v_j + 1; 
  end loop;

  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('asset_cost'), null, to_jsonb(round(v_sum_deal_cost  * 0.7)), in_user_object_id);
  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('asset_amortization'), null, to_jsonb(round(v_sum_deal_cost * 0.07)), in_user_object_id);

  -- Удалим сделку из подготавливаемых для этой корпорации
  v_value := json.get_opt_array(
        data.get_attribute_value_for_update(
          v_corporation_id,
          v_system_corporation_draft_deals_attribute_id,
          null));
  v_value := coalesce(v_value, jsonb '[]') - v_deal_code;
  perform data.set_attribute_value(v_corporation_id, v_system_corporation_draft_deals_attribute_id, null, v_value, in_user_object_id);

  return api_utils.get_objects(in_client,
			  in_user_object_id,
			  jsonb_build_object(
			    'object_codes', jsonb_build_array(v_deal_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
select
  'generate_if_attribute', 
  jsonb_build_object('attribute_code', 
		     'type', 
		     'attribute_value', 
		     'deal', 
		     'function', 
		     'delete_deal_member', 
		     'params',
		     jsonb_build_object('row_num', o.value)), 
  'Функция для удаления участника сделки'
 from generate_series(1, 10) o(value);

 -- Действие для редактирования сделки
CREATE OR REPLACE FUNCTION action_generators.edit_deal(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_is_in_group integer; 
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
begin
   -- Показываем только для автора сделки или мастера, и если она ещё черновик 
  if json.get_opt_integer(data.get_attribute_value(v_user_object_id,
					       v_object_id, 
					       data.get_attribute_id('deal_author')),0) <> v_user_object_id and
    not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_master')), false) or 
     json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('deal_status')),'~') <> 'draft' then
     return null;
   end if;
  
  return jsonb_build_object(
    'edit_deal',
    jsonb_build_object(
      'code', 'edit_deal',
      'name', 'Редактировать сделку',
      'type', 'financial.deal',
      'params', jsonb_build_object('deal_code', data.get_object_code(v_object_id)),
      'user_params', 
       jsonb_build_array(
         jsonb_build_object(
            'code', 'deal_name',
            'type', 'string',
            'description', 'Название сделки',
            'data', jsonb_build_object('min_length', 1),
            'default_value', json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('name'))),
            'min_value_count', 1,
            'max_value_count', 1),
         jsonb_build_object(
            'code', 'description',
            'type', 'string',
            'description', 'Описание сделки',
            'data', jsonb_build_object('min_length', 1, 'multiline', true),
            'default_value', json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('description'))),
            'min_value_count', 1,
            'max_value_count', 1),
         jsonb_build_object(
            'code', 'deal_sector',
            'type', 'objects',
            'description', 'Рынок сделки',
            'data', jsonb_build_object('object_code', 'market', 'attribute_code', 'sectors'),
            'default_value', json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('deal_sector'))),
            'min_value_count', 1,
            'max_value_count', 1),
         jsonb_build_object(
            'code', 'asset_name',
            'type', 'string',
            'description', 'Название актива',
            'data', jsonb_build_object('min_length', 1),
            'default_value', json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('asset_name'))),
            'min_value_count', 1,
            'max_value_count', 1),
         jsonb_build_object(
            'code', 'deal_income',
            'type', 'integer',
            'data', jsonb_build_object('min_value', 0, 'max_value', 1000000000000),
            'description', 'Доходность сделки',
            'default_value', json.get_opt_integer(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('deal_income'))),
            'min_value_count', 1,
            'max_value_count', 1)))
      );
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.edit_deal(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_deal_code text := json.get_string(in_params, 'deal_code');
  v_deal_id integer := data.get_object_id(v_deal_code);
  v_deal_name text := json.get_string(in_user_params, 'deal_name');
  v_description text := json.get_string(in_user_params, 'description');
  v_asset_name text := json.get_string(in_user_params, 'asset_name');
  v_deal_income integer := json.get_integer(in_user_params, 'deal_income');
  v_deal_sector text := json.get_string(in_user_params, 'deal_sector');

  v_ret_val api.result;
begin
  v_ret_val := api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_deal_code),
			    'get_actions', true,
			    'get_templates', true));
  if json.get_opt_string(data.get_attribute_value(in_user_object_id,
					          v_deal_id, 
					          data.get_attribute_id('deal_status')),'~') <> 'draft' then
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Статус сделки изменился!"}';
    return v_ret_val;
   end if;

  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('name'), null, to_jsonb(v_deal_name), in_user_object_id);
  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('deal_author'), null, to_jsonb(in_user_object_id), in_user_object_id);
  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('description'), null, to_jsonb(v_description), in_user_object_id);
  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('deal_sector'), null, to_jsonb(v_deal_sector), in_user_object_id);
  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('asset_name'), null, to_jsonb(v_asset_name), in_user_object_id);
  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('deal_income'), null, to_jsonb(v_deal_income), in_user_object_id);


  return api_utils.get_objects(in_client,
			  in_user_object_id,
			  jsonb_build_object(
			    'object_codes', jsonb_build_array(v_deal_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_attribute', jsonb_build_object('attribute_code', 'type', 'attribute_value', 'deal', 'function', 'edit_deal'), 'Функция для изменения сделки');

-- Действие для удаления сделки
CREATE OR REPLACE FUNCTION action_generators.delete_deal(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_is_in_group integer; 
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
begin
   -- Показываем только для автора сделки или мастера, и если она ещё черновик 
  if json.get_opt_integer(data.get_attribute_value(v_user_object_id,
					       v_object_id, 
					       data.get_attribute_id('deal_author')),0) <> v_user_object_id and
    not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_master')), false) or 
     json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('deal_status')),'~') <> 'draft' then
     return null;
   end if;
  
  return jsonb_build_object(
    'delete_deal',
    jsonb_build_object(
      'code', 'delete_deal',
      'name', 'Удалить сделку',
      'type', 'financial.deal',
      'params', jsonb_build_object('deal_code', data.get_object_code(v_object_id)),
      'warning', 'Вы действительно хотите удалить сделку ' || json.get_string(data.get_attribute_value(v_user_object_id, v_object_id, data.get_attribute_id('name'))) || ' ?'
      )
      );
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

CREATE OR REPLACE FUNCTION actions.delete_deal(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_deal_code text := json.get_string(in_params, 'deal_code');
  v_deal_id integer := data.get_object_id(v_deal_code);
  v_corporation_id integer;

  v_system_corporation_draft_deals_attribute_id integer := data.get_attribute_id('system_corporation_draft_deals');
  v_value jsonb;
  v_value_draft_deals jsonb;
  v_i integer;
  v_ret_val api.result;
begin
  v_ret_val := api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_deal_code),
			    'get_actions', true,
			    'get_templates', true));
  if json.get_opt_string(data.get_attribute_value(in_user_object_id,
					          v_deal_id, 
					          data.get_attribute_id('deal_status')),'~') <> 'draft' then
    v_ret_val.data := v_ret_val.data || jsonb '{"message": "Статус сделки изменился!"}';
    return v_ret_val;
   end if;

  perform data.set_attribute_value_if_changed(v_deal_id, data.get_attribute_id('deal_status'), null, jsonb '"deleted"', in_user_object_id);

  -- Удалим сделку из подготавливаемых для всех корпораций
  for v_i in 1..10 loop
    v_value := data.get_attribute_value(in_user_object_id, v_deal_id, data.get_attribute_id('system_deal_participant' || v_i));
    if v_value is not null then
      v_corporation_id := data.get_object_id(json.get_opt_string(v_value -> 'member'));
      v_value_draft_deals := json.get_opt_array(
        data.get_attribute_value_for_update(
          v_corporation_id,
          v_system_corporation_draft_deals_attribute_id,
          null));
      v_value_draft_deals := coalesce(v_value_draft_deals, jsonb '[]') - v_deal_code;
      perform data.set_attribute_value(v_corporation_id, v_system_corporation_draft_deals_attribute_id, null, v_value_draft_deals, in_user_object_id);
    end if;    
  end loop;

  return api_utils.get_objects(in_client,
			  in_user_object_id,
			  jsonb_build_object(
			    'object_codes', jsonb_build_array(data.get_object_code(in_user_object_id)),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_attribute', jsonb_build_object('attribute_code', 'type', 'attribute_value', 'deal', 'function', 'delete_deal'), 'Функция для удаления сделки');


-- TODO: нагенерировать транзакций и писем

-- TODO: deferred_functions (периодическое начисление денег)