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
  if v_int_value <= 2 then
    return 'очень слабый';
  elsif v_int_value <= 5 then
    return 'слабый';
  elsif v_int_value <= 8 then
    return 'средний';
  elsif v_int_value <= 10 then
    return 'сильный';
  elsif v_int_value <= 12 then
    return 'очень сильный';
  end if;

  return 'экстремально сильный';
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
('system_meta', 'Маркер мета-объекта', 'SYSTEM', null),
('system_mail_contact', 'Маркер объекта, которому можно отправлять письма', 'SYSTEM', null),
('person_race', 'Раса', 'NORMAL', 'person_race'),
('person_state', 'Государство', 'NORMAL', 'person_state'),
('person_job_position', 'Должность', 'NORMAL', null),
('person_biography', 'Биография', 'NORMAL', null),
('person_psi_scale', 'Сила телепата', 'NORMAL', 'person_psi_scale'),
('mail_title', 'Заголовок', 'NORMAL', null),
('system_mail_send_time', 'Реальное время отправки письма', 'SYSTEM', null),
('mail_send_time', 'Время отправки письма', 'NORMAL', null),
('mail_author', 'Автор', 'NORMAL', 'code'),
('mail_receivers', 'Получатели', 'NORMAL', 'codes'),
('mail_body', 'Тело', 'NORMAL', null),
('mail_type', 'Тип письма', 'NORMAL', 'mail_type'),
('inbox', 'Входящие письма', 'INVISIBLE', null),
('outbox', 'Исходящие письма', 'INVISIBLE', null),
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
('news_media', 'Источник новости', 'NORMAL', null),
('news_time', 'Время публикации новости', 'NORMAL', null);

-- Функции для создания связей
insert into data.attribute_value_change_functions(attribute_id, function, params) values
(data.get_attribute_id('type'), 'string_value_to_object', jsonb '{"params": {"person": "persons", "corporation": "corporations", "ship": "ships", "media": "news_hub", "library_category": "library"}}'),
(data.get_attribute_id('system_master'), 'boolean_value_to_object', jsonb '{"object_code": "masters"}'),
(data.get_attribute_id('person_psi_scale'), 'any_value_to_object', jsonb '{"object_code": "telepaths"}'),
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
(data.get_attribute_id('meta_entities'), 'fill_user_object_attribute_if', '{"attribute_code": "type", "attribute_value": "person", "function": "merge_metaobjects", "params": {"object_code": "meta_entities", "attribute_code": "meta_entities"}}', 'Заполнение списка метаобъектов игрока');

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
 
  perform data.set_attribute_value_if_changed(
    v_object_id,
    v_attribute_id,
    null,
    v_content,
    v_object_id);
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

insert into data.attribute_value_fill_functions(attribute_id, function, params, description) values
(data.get_attribute_id('content'), 'fill_object_attribute_if', '{"attribute_code": "type", "attribute_value": "news_hub", "function": "news_hub_content"}', 'Получение списка новостей');


  -- TODO и другие:
  -- news_hub: object_objects[intermediate is null] -> content
  -- person: system_balance -> balance[player]
  -- media{1,3}: object_objects -> content
  -- personal_document_storage: system_value[player] -> content[player]
  -- library: object_objects[intermediate is null] -> content
  -- med_library: object_objects -> content
  -- transactions: system_value[player] -> content[player]
  -- news{1,3}{1,100}: media_name + title -> name
  -- library_category{1,9}: object_objects[intermediate is null] -> content
  -- mailX: system_mail_send_time -> mail_send_time (с использованием формата из параметров)

-- Заполнение атрибутов
select data.set_attribute_value(data.get_object_id('mail_contacts'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('mail_contacts'), data.get_attribute_id('type'), null, jsonb '"mail_contacts"');
select data.set_attribute_value(data.get_object_id('mail_contacts'), data.get_attribute_id('name'), null, jsonb '"Доступные контакты"');

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
  data.set_attribute_value(data.get_object_id('media' || o.value), data.get_attribute_id('name'), null, ('"Media ' || o.value || '"')::jsonb),
  data.set_attribute_value(data.get_object_id('media' || o.value), data.get_attribute_id('description'), null, ('"Самая оперативная, честная и скромная из всех газет во всей вселенной. Читайте только нас! Мы - Media ' || o.value || '!"')::jsonb)
from generate_series(1, 3) o(value);

select
  data.set_attribute_value(data.get_object_id('race' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('race' || o.value), data.get_attribute_id('type'), null, jsonb '"race"'),
  data.set_attribute_value(data.get_object_id('race' || o.value), data.get_attribute_id('name'), null, ('"race' || o.value || '"')::jsonb),
  data.set_attribute_value(data.get_object_id('race' || o.value), data.get_attribute_id('description'), null, ('"Синие и ми-ми-мишные, а может быть зелёные и чешуйчатые, а может быть с костяным наростом, или они все Кош. Кто их знает этих представителей рассы №' || o.value || '!"')::jsonb)
from generate_series(1, 20) o(value);

select
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('type'), null, jsonb '"state"'),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('name'), null, ('"state' || o.value || '"')::jsonb),
  data.set_attribute_value(data.get_object_id('state' || o.value), data.get_attribute_id('description'), null, ('"Их адрес не дом и не улица, их адрес -  state ' || o.value || '!"')::jsonb)s
from generate_series(1, 10) o(value);

select data.set_attribute_value(data.get_object_id('anonymous'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
select data.set_attribute_value(data.get_object_id('anonymous'), data.get_attribute_id('type'), null, jsonb '"person"');
select data.set_attribute_value(data.get_object_id('anonymous'), data.get_attribute_id('name'), null, jsonb '"Аноним"');
select data.set_attribute_value(data.get_object_id('anonymous'), data.get_attribute_id('description'), null, jsonb '"Вы не вошли в систему и работаете в режиме чтения общедоступной информации."');

-- other anonymous

select
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_is_visible'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('type'), null, jsonb '"person"'),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('name'), null, ('"Person ' || o.value || '"')::jsonb),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_mail_contact'), null, jsonb 'true'),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('person_race'), null, ('"race' || (o.value % 20 + 1) || '"')::jsonb),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('person_state'), null, ('"state' || (o.value % 10 + 1) || '"')::jsonb),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('person_job_position'), null, jsonb '"Some job position"'),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('person_biography'), null, jsonb '"Born before 2250, currently live & work on Babylon 5"'),
  data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('system_balance'), null, utils.random_integer(100,10000000)::text::jsonb)
from generate_series(1, 60) o(value);

--   case when o.value % 10 = 0 then data.set_attribute_value(data.get_object_id('person' || o.value), data.get_attribute_id('person_psi_scale'), , utils.random_integer(1,16)::text::jsonb) else null end,
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
  data.set_attribute_value(data.get_object_id('global_notification' || o.value), data.get_attribute_id('notification_description'), null, ('"Global notification ' || o.value || '"')::jsonb),
  data.set_attribute_value(data.get_object_id('global_notification' || o.value), data.get_attribute_id('notification_time'), null, ('"15.02.2258 17:2' || o.value || '"')::jsonb),
  data.set_attribute_value(data.get_object_id('global_notification' || o.value), data.get_attribute_id('type'), null, jsonb '"notification"')
from generate_series(1, 3) o(value);

select
  data.set_attribute_value(data.get_object_id('personal_notification' || o.value), data.get_attribute_id('system_is_visible'), data.get_object_id('person' || o.value), jsonb 'true'),
  data.set_attribute_value(data.get_object_id('personal_notification' || o.value), data.get_attribute_id('notification_description'), null, ('"Personal notification ' || o.value || '"')::jsonb),
  data.set_attribute_value(data.get_object_id('personal_notification' || o.value), data.get_attribute_id('notification_object_code'), null, ('"person' || o.value || '"')::jsonb),
  data.set_attribute_value(data.get_object_id('personal_notification' || o.value), data.get_attribute_id('notification_time'), null, jsonb '"15.02.2258 17:30"'),
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
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('news_title'), null, ('"Заголовок новости news' || o1.value || o2.value || '!"')::jsonb),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('name'), null, ('"media'||o1.value||': Заголовок страницы новости news' || o1.value || o2.value || '!"')::jsonb),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('news_media'), null, ('"media' || o1.value ||'"')::jsonb),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('news_time'), null, ('"2258.02.23 ' || 10 + trunc(o2.value / 10) || ':' || 10 + o1.value * 5 || '"')::jsonb),
  data.set_attribute_value(data.get_object_id('news' || o1.value || o2.value ), data.get_attribute_id('content'), null, ('"Текст новости news' || o1.value || o2.value || '. <br>После активного культурного взаимонасыщения таких, казалось бы разных цивилизаций, как Драззи и Минбари их общества кардинально изменились. Ввиду закрытости последних, стороннему наблюдателю, скорей всего не суждено узнать, как же повлияли воинственные Драззи на высокодуховных Минбарцев, однако у первых изменения, так сказать, на лицо. <br>Почти сразу после первых визитов, спрос на минбарскую культуру взлетел до небес! Ткани, одежда, предметы мебели и прочие диковинные товары заполонили рынки. Активно стали ввозиться всевозможные составы целительного свойства. Например, ставший знаменитым порошок, под названием “Минбарский гребень” завоевал популярность у молодых Драззи. Препарат, якобы, сделан на основе тертого костного образования на черепе минбарца. Многие потребители уверяют, что с его помощью, смогли одержать победу на любовном фронте, однако, ученые уверяют, что тонизирующий эффект, как и происхождение самого препарата не вызывают особого доверия."')::jsonb)
from generate_series(1, 3) o1(value)
join generate_series(1, 100) o2(value) on 1=1;

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
transactions
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
news{1,3}{1,100}
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
  if v_user_object_id = v_test_object_id and (v_object_id is null or v_object_id = v_test_object_id) then
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
  end if;

  return null;
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

-- TODO: deferred_functions (периодическое начисление денег)