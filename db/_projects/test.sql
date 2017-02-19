-- Расширения
insert into data.extensions(code) values
('meta'),
('mail'),
('history'),
('notifications');

-- Параметры
insert into data.params(code, value, description) values
('time_format', jsonb '"dd.mm.2258 hh24:mi"', 'Формат дат'),
('template', jsonb '
{
  "groups": [
    {
      "attributes": ["balance"]
    },
    {
      "attributes": ["transaction_time", "transaction_sum", "transaction_from", "transaction_to", "transaction_description"]
    },
    {
      "attributes": ["person_race", "person_state", "person_psi_scale", "person_job_position"]
    },
    {
      "attributes": ["person_biography"]
    },
    {
      "attributes": ["mail_type", "mail_send_time", "mail_title", "mail_author", "mail_receivers"]
    },
    {
      "attributes": ["news_time", "news_media", "news_title"]
    },
    {
      "attributes": ["mail_body"]
    },
    {
      "attributes": ["corporation_capitalization", "corporation_members", "corporation_asserts"]
    },
    {
      "attributes": ["asset_status", "asset_time", "asset_cost", "asset_corporations"]
    },
    {
      "attributes": ["description", "content"]
    },
    {
      "actions": ["login"]
    },
    {
      "attributes": ["market_volume"]
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
('technicians'),
('pilots'),
('officers'),
('traders'),
('hackers'),
('scientists'),
('corporations'),
('ships'),
('news_hub');

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
select 'corporation' || o.* from generate_series(1, 9) o;

insert into data.objects(code)
select 'asset' || o1.* || o2.* from generate_series(1, 9) o1(value)
join generate_series(1, 50) o2(value) on 1=1;

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

CREATE OR REPLACE FUNCTION attribute_value_description_functions.asset_status(
    in_user_object_id integer,
    in_attribute_id integer,
    in_value jsonb)
  RETURNS text AS
$BODY$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'review' then
    return 'На согласовании';
  when v_text_value = 'normal' then
    return 'Работает';
  end case;

  return null;
end;
$BODY$
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

-- Атрибуты
insert into data.attributes(code, name, type, value_description_function) values
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
('corporation_members', 'Члены корпораций', 'NORMAL', 'codes'),
('corporation_capitalization', 'Капитализация корпорации', 'NORMAL', null),
('corporation_asserts', 'Активы корпорации', 'NORMAL', null),
('asset_corporations', 'Корпорации актива', 'NORMAL', 'codes'),
('asset_time', 'Время создания актива', 'NORMAL', null),
('asset_status', 'Состояние актива', 'NORMAL', 'asset_status'),
('asset_cost', 'Стоимость актива', 'NORMAL', null),
('market_volume', 'Объём рынка', 'NORMAL', null),
('system_balance', 'Остаток на счету', 'SYSTEM', null),
('balance', 'Остаток на счету', 'NORMAL', null),
('system_master', 'Маркер мастерского персонажа', 'SYSTEM', null),
('system_security', 'Маркер персонажа, имеющего доступ к системе безопасности', 'SYSTEM', null),
('system_politician', 'Маркер персонажа-политика', 'SYSTEM', null),
('system_medic', 'Маркер персонажа-медика', 'SYSTEM', null),
('system_technician', 'Маркер персонажа-техника', 'SYSTEM', null),
('system_pilot', 'Маркер персонажа-пилота', 'SYSTEM', null),
('system_officer', 'Маркер персонажа-офицера', 'SYSTEM', null),
('system_trader', 'Маркер персонажа-корпората', 'SYSTEM', null),
('system_hacker', 'Маркер персонажа-хакера', 'SYSTEM', null),
('system_scientist', 'Маркер персонажа-учёного', 'SYSTEM', null),
('system_library_category', 'Категория документа', 'SYSTEM', null),
('news_title', 'Заголовок новости', 'NORMAL', null),
('news_media', 'Источник новости', 'NORMAL', 'code'),
('news_time', 'Время публикации новости', 'NORMAL', null);

-- Функции для создания связей
insert into data.attribute_value_change_functions(attribute_id, function, params) values
(data.get_attribute_id('type'), 'string_value_to_object', jsonb '{"params": {"person": "persons", "corporation": "corporations", "ship": "ships", "media": "news_hub", "library_category": "library"}}'),
(data.get_attribute_id('type'), 'string_value_to_attribute', jsonb '{"params": {"person": {"object_code": "transaction_destinations", "attribute_code": "transaction_destinations"}, "corporation": {"object_code": "transaction_destinations", "attribute_code": "transaction_destinations"}}}'),
(data.get_attribute_id('system_master'), 'boolean_value_to_object', jsonb '{"object_code": "masters"}'),
(data.get_attribute_id('system_psi_scale'), 'any_value_to_object', jsonb '{"object_code": "telepaths"}'),
(data.get_attribute_id('system_security'), 'boolean_value_to_object', jsonb '{"object_code": "security"}'),
(data.get_attribute_id('system_politician'), 'boolean_value_to_object', jsonb '{"object_code": "politicians"}'),
(data.get_attribute_id('system_medic'), 'boolean_value_to_object', jsonb '{"object_code": "medics"}'),
(data.get_attribute_id('system_technician'), 'boolean_value_to_object', jsonb '{"object_code": "technicians"}'),
(data.get_attribute_id('system_pilot'), 'boolean_value_to_object', jsonb '{"object_code": "pilots"}'),
(data.get_attribute_id('system_officer'), 'boolean_value_to_object', jsonb '{"object_code": "officers"}'),
(data.get_attribute_id('system_trader'), 'boolean_value_to_object', jsonb '{"object_code": "traders"}'),
(data.get_attribute_id('system_hacker'), 'boolean_value_to_object', jsonb '{"object_code": "hackers"}'),
(data.get_attribute_id('system_scientist'), 'boolean_value_to_object', jsonb '{"object_code": "scientists"}'),
(data.get_attribute_id('system_mail_contact'), 'boolean_value_to_attribute', jsonb '{"object_code": "mail_contacts", "attribute_code": "mail_contacts"}'),
(data.get_attribute_id('system_meta'), 'boolean_value_to_value_attribute', jsonb '{"object_code": "meta_entities", "attribute_code": "meta_entities"}');

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
(data.get_attribute_id('meta_entities'), 'fill_if_user_object_attribute', '{"blocks": [{"conditions": [{"attribute_code": "type", "attribute_value": "person"}, {"attribute_code": "type", "attribute_value": "anonymous"}], "function": "merge_metaobjects", "params": {"object_code": "meta_entities", "attribute_code": "meta_entities"}}]}', 'Заполнение списка метаобъектов игрока');

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.news_hub_content(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_content jsonb;
  v_attribute_name_id integer := data.get_attribute_id('name');
  v_attribute_news_time_id integer := data.get_attribute_id('news_time');
begin
  select to_jsonb(string_agg(src.dt || ' <a href="babcom:' || src.code || '">' || src.nm || '</a>', E'<br>\n'::text))
  into v_content
  from (
    select
      json.get_string(av_date.value) dt,
      o.code,
      json.get_string(av_name.value) nm
    from data.object_objects oo
    left join data.objects o on
      o.id = oo.object_id
    left join data.attribute_values av_name on
      av_name.object_id = o.id and
      av_name.attribute_id = v_attribute_name_id and
      av_name.value_object_id is null
    left join data.attribute_values av_date on
      av_date.object_id = o.id and
      av_date.attribute_id = v_attribute_news_time_id and
      av_date.value_object_id is null
    where
      oo.parent_object_id = v_object_id and
      oo.intermediate_object_ids is not null
    order by av_date.value desc
  ) src;

  if v_content is null then
    perform data.delete_attribute_value_if_exists(v_object_id, v_attribute_id, null, v_object_id);
  else
    perform data.set_attribute_value_if_changed(
      v_object_id,
      v_attribute_id,
      null,
      v_content);
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.media_content(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_content jsonb;
  v_attribute_name_id integer := data.get_attribute_id('name');
  v_attribute_news_time_id integer := data.get_attribute_id('news_time');
begin
  select to_jsonb(string_agg(src.dt || ' <a href="babcom:' || src.code || '">' || src.nm || '</a>', E'<br>\n'::text))
  into v_content
  from (
    select
      json.get_string(av_date.value) dt,
      o.code,
      json.get_string(av_name.value) nm
    from data.object_objects oo
    left join data.objects o on
      o.id = oo.object_id
    left join data.attribute_values av_name on
      av_name.object_id = o.id and
      av_name.attribute_id = v_attribute_name_id and
      av_name.value_object_id is null
    left join data.attribute_values av_date on
      av_date.object_id = o.id and
      av_date.attribute_id = v_attribute_news_time_id and
      av_date.value_object_id is null
    where
      oo.parent_object_id = v_object_id and
      oo.intermediate_object_ids is null and
      oo.parent_object_id <> oo.object_id
    order by av_date.value desc
  ) src;

  if v_content is null then
    perform data.delete_attribute_value_if_exists(v_object_id, v_attribute_id, null, v_object_id);
  else
    perform data.set_attribute_value_if_changed(
      v_object_id,
      v_attribute_id,
      null,
      v_content);
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
      {"conditions": [{"attribute_code": "type", "attribute_value": "news_hub"}], "function": "news_hub_content"},
      {"conditions": [{"attribute_code": "type", "attribute_value": "media"}], "function": "media_content"},
      {"conditions": [{"attribute_code": "type", "attribute_value": "transactions"}], "function": "value_codes_to_value_links", "params": {"attribute_code": "system_value", "placeholder": "Транзакций нет"}}
    ]
  }', 'Получение списков (новости, транзакции)');

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(data.get_attribute_id('transaction_destinations'), 'fill_if_object_attribute', '{"blocks": [{"conditions": [{"attribute_code": "type", "attribute_value": "transaction_destinations"}], "function": "filter_user_object_code"}]}', 'Получение списка возможных получателей переводов');

CREATE OR REPLACE FUNCTION attribute_value_fill_functions.fill_transaction_name(in_params jsonb)
  RETURNS void AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
  v_attribute_id integer := json.get_integer(in_params, 'attribute_id');
  v_from_id integer :=
    data.get_object_id(
      json.get_string(
        data.get_attribute_value(
          v_user_object_id,
          v_object_id,
          data.get_attribute_id('transaction_from'))));
  v_to_id integer :=
    data.get_object_id(
      json.get_string(
        data.get_attribute_value(
          v_user_object_id,
          v_object_id,
          data.get_attribute_id('transaction_to'))));
begin
  assert v_from_id = v_user_object_id or v_to_id = v_user_object_id;

  perform data.set_attribute_value_if_changed(
    v_object_id,
    v_attribute_id,
    v_user_object_id,
    to_jsonb(
      json.get_string(data.get_attribute_value(v_user_object_id, v_object_id, data.get_attribute_id('transaction_time'))) || ', ' ||
      case when v_from_id = v_user_object_id then 'исходящий' else 'входящий' end || ' перевод на сумму ' ||
      json.get_integer(data.get_attribute_value(v_user_object_id, v_object_id, data.get_attribute_id('transaction_sum'))) || '. ' ||
      case when v_from_id = v_user_object_id then 'Получатель' else 'Отправитель' end || ': ' ||
      json.get_string(
        data.get_attribute_value(
          v_user_object_id,
          case when v_from_id = v_user_object_id then v_to_id else v_from_id end,
          v_attribute_id)) ||
      '. Сообщение: ' ||
      json.get_string(data.get_attribute_value(v_user_object_id, v_object_id, data.get_attribute_id('transaction_description')))));
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(data.get_attribute_id('name'), 'fill_if_object_attribute', '{"blocks": [{"conditions": [{"attribute_code": "type", "attribute_value": "transaction"}], "function": "fill_transaction_name"}]}', 'Получение имени транзакции');

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(data.get_attribute_id('balance'), 'fill_user_attribute_from_attribute', '{"attribute_code": "system_balance"}', 'Получение состояния счёта');

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(data.get_attribute_id('person_psi_scale'), 'fill_user_attribute_from_attribute', '{"attribute_code": "system_psi_scale"}', 'Получение рейтинга телепата');

  -- TODO и другие:
  -- personal_document_storage: system_value[player] -> content[player]
  -- library: object_objects[intermediate is null] -> content
  -- med_library: object_objects -> content
  -- library_category{1,9}: object_objects[intermediate is null] -> content
  -- mailX: system_mail_send_time -> mail_send_time (с использованием формата из параметров)

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

select data.set_attribute_value(data.get_object_id('traders'), data.get_attribute_id('system_priority'), null, jsonb '40');
select data.set_attribute_value(data.get_object_id('traders'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('traders'), data.get_attribute_id('name'), null, jsonb '"Корпораты"');

select data.set_attribute_value(data.get_object_id('hackers'), data.get_attribute_id('system_priority'), null, jsonb '80');
select data.set_attribute_value(data.get_object_id('hackers'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('hackers'), data.get_attribute_id('name'), null, jsonb '"Хакеры"');

select data.set_attribute_value(data.get_object_id('scientists'), data.get_attribute_id('system_priority'), null, jsonb '50');
select data.set_attribute_value(data.get_object_id('scientists'), data.get_attribute_id('type'), null, jsonb '"group"');
select data.set_attribute_value(data.get_object_id('scientists'), data.get_attribute_id('name'), null, jsonb '"Учёные"');

select data.set_attribute_value(data.get_object_id('corporations'), data.get_attribute_id('system_is_visible'), data.get_object_id('traders'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('corporations'), data.get_attribute_id('type'), null, jsonb '"group"');
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

select
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('type'), null, jsonb '"state"'),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('name'), null, to_jsonb('state' || o.value)),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('description'), null, to_jsonb('Их адрес не дом и не улица, их адрес -  state ' || o.value || '!'))
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
  end
from generate_series(1, 60) o(value);

-- other person{1,60}
/*
system_master
system_security
system_politician
system_medic
system_technician
system_pilot
system_officer
system_trader
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
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('news_time'), null, to_jsonb('2258.02.23 ' || 10 + trunc(o2.value / 10) || ':' || 10 + o1.value * 5)),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('content'), null, to_jsonb('Текст новости news' || o1.value || o2.value || '. <br>После активного культурного взаимонасыщения таких, казалось бы разных цивилизаций, как Драззи и Минбари их общества кардинально изменились. Ввиду закрытости последних, стороннему наблюдателю, скорей всего не суждено узнать, как же повлияли воинственные Драззи на высокодуховных Минбарцев, однако у первых изменения, так сказать, на лицо. <br>Почти сразу после первых визитов, спрос на минбарскую культуру взлетел до небес! Ткани, одежда, предметы мебели и прочие диковинные товары заполонили рынки. Активно стали ввозиться всевозможные составы целительного свойства. Например, ставший знаменитым порошок, под названием “Минбарский гребень” завоевал популярность у молодых Драззи. Препарат, якобы, сделан на основе тертого костного образования на черепе минбарца. Многие потребители уверяют, что с его помощью, смогли одержать победу на любовном фронте, однако, ученые уверяют, что тонизирующий эффект, как и происхождение самого препарата не вызывают особого доверия.'))
from generate_series(1, 3) o1(value)
join generate_series(1, 100) o2(value) on 1=1;

select data.set_attribute_value(data.get_object_id('transactions'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('transactions'), data.get_attribute_id('type'), null, jsonb '"transactions"');
select data.set_attribute_value(data.get_object_id('transactions'), data.get_attribute_id('name'), null, jsonb '"История операций"');
select data.set_attribute_value(data.get_object_id('transactions'), data.get_attribute_id('system_meta'), data.get_object_id('persons'), jsonb 'true');

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
system_trader
system_hacker
system_scientist
system_library_category
*/
/*
personal_document_storage
library
med_library
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
market
meta_entities
station_weapon{1,4}
station_reactor{1,4}
ship_weapon{1,2}
ship_reactor{1,2}
corporation{1,9}
asset{1,9}{1,50}
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
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_opt_integer(in_params, null, 'object_id');
  v_test_object_id integer := json.get_integer(in_params, 'test_object_id');
begin
  if v_user_object_id != v_test_object_id or v_object_id is not null then
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
    in_notification_object_code text)
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
  perform data.set_attribute_value(v_notification_id, data.get_attribute_id('notification_time'), null, to_jsonb(to_char(now(), data.get_string_param('time_format'))), in_user_object_id);
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
    in_object_id integer,
    in_description text,
    in_sum integer)
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

  insert into data.objects(id) values(default)
  returning id, code into v_transaction_id, v_transaction_code;

  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('system_is_visible'), in_user_object_id, jsonb 'true', in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('system_is_visible'), in_object_id, jsonb 'true', in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('system_is_visible'), data.get_object_id('masters'), jsonb 'true', in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('type'), null, jsonb '"transaction"', in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('transaction_from'), null, to_jsonb(data.get_object_code(in_user_object_id)), in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('transaction_to'), null, to_jsonb(data.get_object_code(in_object_id)), in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('transaction_time'), null, to_jsonb(to_char(now(), data.get_string_param('time_format'))), in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('transaction_description'), null, to_jsonb(in_description), in_user_object_id);
  perform data.set_attribute_value(v_transaction_id, data.get_attribute_id('transaction_sum'), null, to_jsonb(in_sum), in_user_object_id);

  v_transactions_value := data.get_attribute_value_for_update(v_transactions_object_id, v_transactions_system_value_attribute_id, in_user_object_id);
  perform json.get_opt_string_array(v_transactions_value);

  v_transactions_value := coalesce(v_transactions_value, jsonb '[]') || jsonb_build_array(v_transaction_code);
  perform data.set_attribute_value(v_transactions_object_id, v_transactions_system_value_attribute_id, in_user_object_id, v_transactions_value, in_user_object_id);

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
begin
  assert v_sum > 0;

  if in_user_object_id < v_receiver_id then
    v_user_balance := data.get_attribute_value_for_update(in_user_object_id, v_system_balance_attribute_id, null);
    v_receiver_balance := data.get_attribute_value_for_update(v_receiver_id, v_system_balance_attribute_id, null);
  else
    v_receiver_balance := data.get_attribute_value_for_update(v_receiver_id, v_system_balance_attribute_id, null);
    v_user_balance := data.get_attribute_value_for_update(in_user_object_id, v_system_balance_attribute_id, null);
  end if;

  if coalesce(v_user_balance, 0) < v_sum then
    return
      api_utils.get_objects(
        in_client,
        in_user_object_id,
        jsonb_build_object(
          'object_codes', jsonb_build_array(data.get_object_code(in_user_object_id)),
          'get_actions', true,
          'get_templates', true)) ||
      jsonb '{"message": "Недостаточно средств!"}';
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
    v_receiver_id,
    v_description,
    v_sum);

  perform actions.create_notification(
    in_user_object_id,
    array[v_receiver_id],
    (
      'Входящий перевод на сумму ' ||
      v_sum ||
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
  v_user_object_id integer;
  v_system_balance_attribute_id integer;
  v_balance jsonb;
  v_balance_value integer;
  
begin
  if v_object_id is not null then
    return null;
  end if;

  v_user_object_id := json.get_integer(in_params, 'user_object_id');
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
        'name', 'Денежный перевод',
        'type', 'finances.transfer',
        'disabled', true));
  end if;

  return jsonb_build_object(
    'transfer',
    jsonb_build_object(
      'code', 'transfer',
      'name', 'Денежный перевод',
      'type', 'finances.transfer',
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
  LANGUAGE plpgsql IMMUTABLE
  COST 100;

insert into data.action_generators(function, params, description)
values('generate_if_user_attribute', jsonb_build_object('attribute_code', 'type', 'attribute_value', 'person', 'function', 'transfer'), 'Функция для перевода средств');

-- TODO: нагенерировать транзакций и писем

-- TODO: deferred_functions (периодическое начисление денег)