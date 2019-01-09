-- drop function data.init();

create or replace function data.init()
returns void
volatile
as
$$
begin
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  (
    'actions_function',
    null,
    'Функция, вызываемая перед получением действий объекта, string. Вызывается с параметрами (object_id, actor_id) и возвращает действия.',
    'system',
    null,
    null,
    false
  ),
  (
    'actor_function',
    null,
    'Функция, вызываемая перед получением заголовка и подзаголовка актора, string. Вызывается с параметром (object_id).',
    'system',
    null,
    null,
    false
  ),
  ('content', null, 'Массив идентификаторов объектов списка, integer[]', 'hidden', 'full', null, false),
  (
    'full_card_function',
    null,
    'Функция, вызываемая перед получением полной карточки объекта, string. Вызывается с параметрами  (object_id, actor_id).',
    'system',
    null,
    null,
    false
  ),
  ('is_visible', null, 'Определяет, доступен ли объект текущему актору, boolean', 'system', null, null, true),
  (
    'list_actions_function',
    null,
    'Функция, вызываемая перед получением действий объекта списка, string. Вызывается с параметрами (object_id, list_object_id, actor_id) и возвращает действия.',
    'system',
    null,
    null,
    false
  ),
  (
    'mini_card_function',
    null,
    'Функция, вызываемая перед получением миникарточки объекта, string. Вызывается с параметрами (object_id, actor_id).',
    'system',
    null,
    null,
    false
  ),
  (
    'priority',
    null,
    'Приоритет группы, integer. Для стабильной работы приоритет всех групп (объектов, включающих другие объекты) должен быть уникальным. Значение приоритета по умолчанию - 0.',
    'system',
    null,
    null,
    false
  ),
  ('redirect', null, 'Содержит идентификатор объекта, который должен быть возвращён вместо запрошенного при получении полной карточки объекта, integer.', 'system', null, null, true),
  ('subtitle', null, 'Подзаголовок, string', 'normal', null, null, true),
  ('temporary_object', null, 'Атрибут, наличие которого говорит о том, что открытый объект не нужно сохранять в истории', 'hidden', 'full', null, false),
  ('title', null, 'Заголовок, string', 'normal', null, null, true),
  (
    'touch_function',
    null,
    'Функция, вызываемая при смахивании уведомления, string. Вызывается с параметрами (object_id, actor_id).'
    'system',
    null,
    null,
    false
  ),
  ('type', null, 'Тип объекта, string', 'hidden', null, null, true);
end;
$$
language 'plpgsql';
