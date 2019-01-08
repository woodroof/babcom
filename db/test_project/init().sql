-- drop function test_project.init();

create or replace function test_project.init()
returns void
volatile
as
$$
declare
  v_type_attribute_id integer := data.get_attribute_id('type');
  v_title_attribute_id integer := data.get_attribute_id('title');
  v_subtitle_attribute_id integer := data.get_attribute_id('subtitle');
  v_is_visible_attribute_id integer := data.get_attribute_id('is_visible');
  v_content_attribute_id integer := data.get_attribute_id('content');
  v_description_attribute_id integer;
  v_description2_attribute_id integer;
  v_description3_attribute_id integer;
  v_description4_attribute_id integer;
  v_empty1_attribute_id integer;
  v_integer_attribute_id integer;
  v_float_attribute_id integer;
  v_integer2_attribute_id integer;
  v_float2_attribute_id integer;
  v_default_login_id integer;
  v_menu_id integer;
  v_notifications_id integer;
  v_test_id integer;
  v_not_found_object_id integer;
  v_test_num integer := 2;
begin
  insert into data.attributes(code, description, type, card_type, can_be_overridden)
  values('description', 'Текстовый блок с развёрнутым описанием очередного теста, string', 'normal', 'full', true)
  returning id into v_description_attribute_id;

  insert into data.attributes(code, description, type, card_type, can_be_overridden)
  values('description2', 'Дополнительное текстовое поле в первой безымянной группе, string', 'normal', 'full', true)
  returning id into v_description2_attribute_id;

  insert into data.attributes(code, description, type, card_type, can_be_overridden)
  values('description3', 'Дополнительное текстовое поле во второй безымянной группе, string', 'normal', 'full', true)
  returning id into v_description3_attribute_id;

  insert into data.attributes(code, description, type, card_type, can_be_overridden)
  values('empty1', 'Атрибут без значения в именованной группе, string', 'normal', 'full', true)
  returning id into v_empty1_attribute_id;

  insert into data.attributes(code, description, type, card_type, can_be_overridden)
  values('description4', 'Текстовое поле в именованной группе, string', 'normal', 'full', true)
  returning id into v_description4_attribute_id;

  insert into data.attributes(code, description, type, card_type, can_be_overridden)
  values('integer', 'integer-атрибут', 'normal', 'full', true)
  returning id into v_integer_attribute_id;

  insert into data.attributes(code, description, type, card_type, can_be_overridden)
  values('float', 'float-атрибут', 'normal', 'full', true)
  returning id into v_float_attribute_id;

  insert into data.attributes(code, description, value_description_function, type, card_type, can_be_overridden)
  values('integer2', 'integer-атрибут с описанием значения', 'test_project.test_value_description_function', 'normal', 'full', true)
  returning id into v_integer2_attribute_id;

  insert into data.attributes(code, description, value_description_function, type, card_type, can_be_overridden)
  values('float2', 'float-атрибут с описанием значения', 'test_project.test_value_description_function', 'normal', 'full', true)
  returning id into v_float2_attribute_id;

  -- Создадим актора по умолчанию, который является первым тестом
  insert into data.objects(code) values('test1') returning id into v_test_id;

  -- Создадим объект для страницы 404
  insert into data.objects(code) values('not_found') returning id into v_not_found_object_id;

  -- Логин по умолчанию
  insert into data.logins(code) values('default_login') returning id into v_default_login_id;
  insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_test_id);

  insert into data.params(code, value, description) values
  ('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию'),
  ('not_found_object_id', to_jsonb(v_not_found_object_id), 'Идентификатор объекта, отображаемого в случае, если актору недоступен какой-то объект (ну или он реально не существует)'),
  (
    'template',
    jsonb
    '{
      "groups": [
        {
          "attributes": ["description", "integer", "float", "integer2", "float2", "description2"]
        },
        {
          "attributes": ["description3"]
        },
        {
          "name": "Короткое имя группы",
          "attributes": ["empty1", "description4"]
        }
      ]
    }',
    'Шаблон'
  );

  -- Также для работы нам понадобится пустой объект меню
  insert into data.objects(code) values('menu') returning id into v_menu_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_menu_id, v_type_attribute_id, jsonb '"menu"'),
  (v_menu_id, v_is_visible_attribute_id, jsonb 'true');

  -- И пустой список уведомлений
  insert into data.objects(code) values('notifications') returning id into v_notifications_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_notifications_id, v_type_attribute_id, jsonb '"notifications"'),
  (v_notifications_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_notifications_id, v_content_attribute_id, jsonb '[]');

  -- 404
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_not_found_object_id, v_type_attribute_id, jsonb '"not_found"'),
  (v_not_found_object_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_not_found_object_id, v_title_attribute_id, jsonb '"404"'),
  (v_not_found_object_id, v_subtitle_attribute_id, jsonb '"Not found"'),
  (v_not_found_object_id, v_description_attribute_id, jsonb '"Это не те дроиды, которых вы ищете."');

  -- Тесты
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Добрый день!
Если приложение было запущено первый раз, то первое, что вы должны были увидеть (не считая возможных лоадеров) — это этот текст.
У нас сейчас пустое меню, пустой список непрочитанных уведомлений, а список акторов состоит из одного объекта — того, который открыт прямо сейчас.

Проверка 1: Этот текст разбит на строки. В частности, новая строка начинается сразу после текста "Добрый день!".
Так, если клиент выводит текст в разметке HTML, то полученные от сервера символы перевода строки должны преобразовываться в теги <br>.

Проверка 2: Если клиент преобразует получаемый от сервера текст в какую-то разметку, то все полученные данные должны экранироваться.
Если клиент использует HTML, то он должен экранировать три символа: амперсанд, меньше и больше. Так, в предыдущем пункте должен быть текст br, окружённый символами "меньше" и "больше", а в тексте далее должен быть явно виден символ "амперсанд" и не должно быть символа "больше": &gt;.

Проверка 3: После запуска приложения пользователю не показывали какие-то диалоги.
Приложение само запросило с сервера список акторов, само выбрало в качестве активного первый (в конце концов, в большинстве случаев список будет состоять из одного пункта, а мы не хотим заставлять пользователя делать лишние действия) и само же открыло объект этого выбранного актора.

Проверка 4: Ниже есть ссылка с именем "Продолжить", ведущая на следующий тест. Приложение по нажатию на эту ссылку должно перейти к следующему объекту :)

[Продолжить](babcom:test' || v_test_num || ')')
  );

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Форматирование.
Markdown — формат, который все реализуют по-разному, поэтому мы не требуем, чтобы все сложные случаи обрабатывались одинаково.
Также клиенты могут просто использовать библиотеки и поддерживать какие-то возможности, не описанные в нашем документе. Их мы тоже не тестируем :grinning:

Проверка 1: Слово *italic* должно быть наклонным, фраза _italic phase_ — тоже.
Проверка 2: Начертание слова **жирный** должно отличаться большей насыщенностью линий, как и начертание фразы __жирный текст__.
Проверка 3: Вложенное форматирование также должно обрабатываться правильно: ***жирное** слово внутри наклонного текста*, __*наклонное* слово внутри жирного текста__.
Проверка 4: И, конечно же, ~~зачёркнутое~~ слово.
Проверка 4: Наконец, на ссылки форматирование тоже должно распространяться. Так, ссылка "Далее" должна быть жирной.

**[Продолжить](babcom:test' || v_test_num || ')**')
  );

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Проверяем вывод нетекстовых атрибутов.

Проверка: Ниже выведены числа -42 и 0.0314159265 (именно так, а не в экспоненциальной записи!).')
  ),
  (v_test_id, v_integer_attribute_id, jsonb '-42'),
  (v_test_id, v_float_attribute_id, jsonb '0.0314159265'),
  (
    v_test_id,
    v_description2_attribute_id,
    to_jsonb(text
'[Продолжить](babcom:test' || v_test_num || ')')
  );

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Проверяем вывод описаний значений атрибутов.

Проверка: Ниже выведены строки "минус сорок два" и "π / 100".')
  ),
  (v_test_id, v_integer2_attribute_id, jsonb '-42'),
  (v_test_id, v_float2_attribute_id, jsonb '0.0314159265'),
  (
    v_test_id,
    v_description2_attribute_id,
    to_jsonb(text
'[Продолжить](babcom:test' || v_test_num || ')')
  );

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Проверяем вывод описаний значений атрибутов с форматированием.

Проверка: Ниже выведена жирная строка "один" и наклонная строка "два".')
  ),
  (v_test_id, v_integer2_attribute_id, jsonb '1'),
  (v_test_id, v_float2_attribute_id, jsonb '2'),
  (
    v_test_id,
    v_description2_attribute_id,
    to_jsonb(text
'[Продолжить](babcom:test' || v_test_num || ')')
  );

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Теперь мы проверяем, как обрабатывается несколько групп и несколько атрибутов в одной группе.')
  ),
  (
    v_test_id,
    v_description2_attribute_id,
    to_jsonb(text
'Проверка 1: Эта строка находится в новом атрибуте. Она должна быть отделена от предыдущей, причём желательно, чтобы это разделение было визуально отлично от обычного начала новой строки.')
  ),
  (
    v_test_id,
    v_description3_attribute_id,
    to_jsonb(text
'Проверка 2: Эта строка находится в новой группе. Должно быть явно видно, где закончилась предыдущая группа и началась новая.

[Продолжить](babcom:test' || v_test_num || ')')
  );

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_empty1_attribute_id, null),
  (
    v_test_id,
    v_description4_attribute_id,
    to_jsonb(text
'Проверим вывод групп с именем и пустых атрибутов.

Проверка 1: Перед этим атрибутом в шаблоне идёт другой атрибут, но у него нет значения, имени и описания значения. Такой атрибут просто не должен выводиться, т.е. текст "Проверим вывод..." должен быть в самом верху группы, никаких дополнительных пропусков быть не должно.

Проверка 2: У этой группы есть имя. Мы должны видеть текст "Короткое имя группы".

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Тест N
  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'TEMPLATE

[Продолжить](babcom:test' || v_test_num || ')')
  );
end;
$$
language 'plpgsql';
