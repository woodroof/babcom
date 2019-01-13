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
  v_actions_function_attribute_id integer := data.get_attribute_id('actions_function');
  v_description_attribute_id integer;

  v_menu_id integer;
  v_notifications_id integer;

  v_test_id integer;
  v_test_num integer := 2;

  v_template_groups jsonb[];
begin
  -- Атрибут для какого-то текста
  insert into data.attributes(code, type, card_type, can_be_overridden)
  values('description', 'normal', 'full', true)
  returning id into v_description_attribute_id;

  -- И первая группа в шаблоне
  v_template_groups := array_append(v_template_groups, jsonb '{"code": "common", "attributes": ["description"], "actions": ["action"]}');

  -- Создадим актора по умолчанию, который является первым тестом
  insert into data.objects(code) values('test1') returning id into v_test_id;

  -- Создадим объект для страницы 404
  declare
    v_not_found_object_id integer;
  begin
    insert into data.objects(code) values('not_found') returning id into v_not_found_object_id;
    insert into data.params(code, value, description)
    values('not_found_object_id', to_jsonb(v_not_found_object_id), 'Идентификатор объекта, отображаемого в случае, если актору недоступен какой-то объект (ну или он реально не существует)');

    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_not_found_object_id, v_type_attribute_id, jsonb '"not_found"'),
    (v_not_found_object_id, v_is_visible_attribute_id, jsonb 'true'),
    (v_not_found_object_id, v_title_attribute_id, jsonb '"404"'),
    (v_not_found_object_id, v_subtitle_attribute_id, jsonb '"Not found"'),
    (v_not_found_object_id, v_description_attribute_id, jsonb '"Это не те дроиды, которых вы ищете."');
  end;

  -- Логин по умолчанию
  declare
    v_default_login_id integer;
  begin
    insert into data.logins(code) values('default_login') returning id into v_default_login_id;
    insert into data.login_actors(login_id, actor_id) values(v_default_login_id, v_test_id);

    insert into data.params(code, value, description)
    values('default_login_id', to_jsonb(v_default_login_id), 'Идентификатор логина по умолчанию');
  end;

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

  -- Базовый тест:
  -- - пустые заголовки, подзаголовки, меню, список уведомлений
  -- - переводы строк
  -- - экранирование
  -- - автовыбор актора при старте приложения
  -- - только атрибуты из шаблона
  -- - ссылка

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
Единственный актор в списке не имеет ни заголовка, ни подзаголовка.

Проверка 1: Этот текст разбит на строки. В частности, новая строка начинается сразу после текста "Добрый день!".
Так, если клиент выводит текст в разметке HTML, то полученные от сервера символы перевода строки должны преобразовываться в теги <br>.

Проверка 2: Если клиент преобразует получаемый от сервера текст в какую-то разметку, то все полученные данные должны экранироваться.
Если клиент использует HTML, то он должен экранировать три символа: амперсанд, меньше и больше. Так, в предыдущем пункте должен быть текст br, окружённый символами "меньше" и "больше", а в тексте далее должен быть явно виден символ "амперсанд" и не должно быть символа "больше": &gt;.

Проверка 3: Эта строка отделена от предыдущей пустой строкой (т.е. есть два перевода строки).

Проверка 4: После запуска приложения пользователю не показывали какие-то диалоги.
Приложение само запросило с сервера список акторов, само выбрало в качестве активного первый (в конце концов, в большинстве случаев список будет состоять из одного пункта, а мы не хотим заставлять пользователя делать лишние действия) и само же открыло объект этого выбранного актора.

Проверка 5: Приложение выводит только заголовок, подзаголовок и атрибуты, присутствующие в шаблоне. В данном конкретном случае нигде не выведен тип объекта ("test").
Считаем, что приложение честно не выводит атрибуты, отсутствующие в шаблоне и не являющиеся заголовком или подзаголовком, и верим, что атрибут с кодом "type" не обрабатывается особым образом :)

Проверка 6: Ниже есть ссылка с именем "Продолжить", ведущая на следующий тест. Приложение по нажатию на эту ссылку должно перейти к следующему объекту.

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Форматирование

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
Проверка 5: Наконец, на ссылки форматирование тоже должно распространяться. Так, ссылка "Далее" должна быть жирной.

**[Продолжить](babcom:test' || v_test_num || ')**')
  );

  -- Несколько атрибутов в группе

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s", "%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'description',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'Проверяем, как обрабатывается несколько атрибутов в одной группе.')
    ),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb(text
'**Проверка:** Эта строка находится в новом атрибуте. Она должна быть отделена от предыдущей, причём желательно, чтобы это разделение было визуально отлично от обычного начала новой строки.

[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Вывод чисел

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
    v_int_attr_id integer;
    v_double_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'integer', 'normal', 'full', true)
    returning id into v_int_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'double', 'normal', 'full', true)
    returning id into v_double_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'description',
          v_test_prefix || 'integer',
          v_test_prefix || 'double',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'Проверяем вывод нетекстовых атрибутов.

**Проверка:** Ниже выведены числа -42 и 0.0314159265 (именно так, а не в экспоненциальной записи!).')
    ),
    (v_test_id, v_int_attr_id, jsonb '-42'),
    (v_test_id, v_double_attr_id, jsonb '0.0314159265'),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Описания значения атрибутов

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
    v_int_attr_id integer;
    v_double_attr_id integer;
    v_string_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'integer', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_int_attr_id;

    insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'double', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_double_attr_id;

    insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'string', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_string_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s", "%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'description',
          v_test_prefix || 'integer',
          v_test_prefix || 'double',
          v_test_prefix || 'string',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'Проверяем вывод описаний значений атрибутов.

**Проверка:** Ниже выведены строки "минус сорок два", "π / 100" и "∫x dx = ½x² + C".')
    ),
    (v_test_id, v_int_attr_id, jsonb '-42'),
    (v_test_id, v_double_attr_id, jsonb '0.0314159265'),
    (v_test_id, v_string_attr_id, jsonb '"integral"'),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Описания значения атрибутов с форматированием

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
    v_int1_attr_id integer;
    v_int2_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'integer1', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_int1_attr_id;

    insert into data.attributes(code, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'integer2', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_int2_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s", "%s", "%s", "%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'description',
          v_test_prefix || 'integer1',
          v_test_prefix || 'integer2',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'Проверяем вывод описаний значений атрибутов с форматированием.

**Проверка:** Ниже выведена жирная строка "один" и наклонная строка "два".')
    ),
    (v_test_id, v_int1_attr_id, jsonb '1'),
    (v_test_id, v_int2_attr_id, jsonb '2'),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Несколько групп

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s"]}',
          v_test_prefix || 'group1',
          v_test_prefix || 'description')::jsonb);
    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s"]}',
          v_test_prefix || 'group2',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'Теперь мы проверяем, как обрабатывается несколько групп.')
    ),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb(text
'**Проверка:** Эта строка находится в новой группе. Должно быть явно видно, где закончилась предыдущая группа и началась новая.

[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Группы с именем

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "name": "Короткое имя группы", "attributes": ["%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'description')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attr_id,
      to_jsonb(text
'**Проверка:** У этой группы есть имя. Мы должны видеть текст "Короткое имя группы".

[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Имена у групп и атрибутов

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_short_attr_id integer;
    v_long_attr_id integer;
    v_short_value_attr_id integer;
    v_long_value_descr_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, name, type, card_type, can_be_overridden)
    values(v_test_prefix || 'short_name', 'Атрибут 1', 'normal', 'full', true)
    returning id into v_short_attr_id;

    insert into data.attributes(code, name, type, card_type, can_be_overridden)
    values(v_test_prefix || 'long_name', 'Атрибут с очень длинным именем, которое нельзя так просто обрезать — оно очень важно для понимания назначения значения, его смысла, глубинной сути, места во вселенной и связи со значениями других атрибутов', 'normal', 'full', true)
    returning id into v_long_attr_id;

    insert into data.attributes(code, name, type, card_type, can_be_overridden)
    values(v_test_prefix || 'short_name_value', 'Атрибут 3', 'normal', 'full', true)
    returning id into v_short_value_attr_id;

    insert into data.attributes(code, name, value_description_function, type, card_type, can_be_overridden)
    values(v_test_prefix || 'long_name_value_description', 'Ещё один атрибут с длинным именем, которое почти наверняка не поместится в одну строку на современных телефонах', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_long_value_descr_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "name": "Тестовые данные", "attributes": ["%s", "%s", "%s", "%s", "%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'short_name',
          v_test_prefix || 'long_name',
          v_test_prefix || 'short_name_value',
          v_test_prefix || 'long_name_value_description',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (
      v_test_id,
      v_description_attribute_id,
      to_jsonb(text
'Теперь имя будет и у группы, и у её атрибутов.

**Проверка 1:** Ниже есть ещё одна группа с именем "Тестовые данные".
**Проверка 2:** Первый атрибут в группе имеет имя "Атрибут 1" и не имеет значения и описания значения.
**Проверка 3:** Второй атрибут имеет длинное имя, которое не влезает в одну строку, начинается с "Атрибут с очень" и не имеет значения и описания значения.
**Проверка 4:** Третий атрибут имеет имя "Атрибут 3" и значение "100".
**Проверка 5:** Четвёртый атрибут имеет имя, начинающееся с "Ещё один атрибут" и также не влезающее в одну строку. Атрибут имеет довольно длинное описание значения, начинающееся с "Lorem ipsum".
**Проверка 6:** Слово ipsum должно быть жирным.
**Проверка 7:** Все атрибуты идут именно в указанном порядке.')
    ),
    (v_test_id, v_short_attr_id, null),
    (v_test_id, v_long_attr_id, null),
    (v_test_id, v_short_value_attr_id, jsonb '100'),
    (v_test_id, v_long_value_descr_attr_id, jsonb '"lorem ipsum"'),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Скроллирование

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Скроллинг.

Ниже представлен большой текст, который гарантированно не войдёт на экран. Клиент должен уметь скроллировать содержимое объекта, чтобы пользователь мог ознакомиться со всей информацией. Читать текст ниже не обязательно, просто промотайте до кнопки "Далее" :)

Человечество – то, что описывает и определяет Солнечную Систему в 24-ом веке. Можно было бы возразить, что планеты вращались по своим орбитам задолго до появления Человечества и продолжат вращаться много позже его исчезновения, а Солнце и вовсе будет светить практически вечно... Но это был бы пустой звук – всё равно что сообщить, что вода мокрая, а горизонт событий недостижим. Без Человека Солнечная Система оставалась бы лишь горсткой камней вокруг огненного шара.
В начале 22-го века Человечество вырвалось с родной планеты и заполонило пространство вокруг. И теперь, спустя всего 200 лет, трудно найти точку в космосе, не затронутую интересами Человека, его действием, волей или мыслью. От солнечных обсерваторий на Меркурии до станций исследования глубокого космоса за орбитой Сатурна – везде есть Человек и его творения.
Однако что есть Человек и что есть Человечество? Так ли едино то общество, которое мы называем этим словом? Так ли похожи друг на друга те, кто его составляет? Традиционалисты скажут: “нет”. Глобалисты скажут: “да”.
Пожалуй, по-настоящему единым человеческое общество было в начале 22-го века. Новый мировой порядок, установленный на Земле, в кратчайшие сроки – менее 50 лет – позволил избавить планету от голода, низкого уровня жизни и даже войн. Политика толерантности, провозглашённая на всей планете после 25-летнего глобального кризиса (называемого также Третьей мировой или Террористической войной), стала краеугольным камнем нового общественного устройства. 
Технический прогресс позволил распределить блага, ранее доступные только “золотому” миллиарду, среди всего населения. Отмена национальных государств и границ высвободила огромные ресурсы, которые до сих пор тратились на поддержание суверенитетов – армию, взаимное налогообложение и т.д.
В конце концов принятие Закона о до-гражданах остановило социально-финансовую гонку, заложенную ещё англо-саксонским доминированием. Право решать за всех перешло к самым активным и ответственным, а не богатым и знаменитым. Остальным же гарантировали пожизненные социальные блага.
Именно это общество смогло осуществить давнюю мечту Человечества – космическую экспансию. Началом её можно считать создание в 2130-м году колонии на Марсе. В отличие от научной станции, к тому моменту существовавшей на красной планете уже почти 100 лет, колония должна была стать крупным, населенным, индустриально развитым, самодостаточным форпостом Человечества.
Идею широко поддержали на Земле. Вслед за первопроходцами сотни тысяч людей вызвались покинуть родной дом и спокойную жизнь ради тяжелого труда на благо всей Человеческой цивилизации.
Менее чем за 30 лет население Марса увеличилось до нескольких миллионов и продолжало стремительно расти. Поддерживаемые прямыми субсидиями ООН, крупные корпорации активно строили на Марсе заводы, рекрутировали и вывозили рабочих с семьями, организовывали для них инфраструктуру. В течение каких-то десятков лет на другой планете создали крупное индустриальное общество. И вскоре это обернулось проблемой.
Марсианская колония разрослась стремительно – прежде всего, благодаря энтузиастам, её строившим. Они оказались людьми совершенно иного склада, непохожими на большинство землян. Стойкие, целеустремленные, горящие идеей обустройства новой планеты. Они готовы были жить и трудиться в тяжелейших психологических и физических условиях: при постоянной опасности погибнуть, минимальных социальных благах, нехватке воды и еды. Неудивительно, что такими людьми оказалось почти невозможно управлять извне.
Пока на Земле разбивали парки на месте бывших заводов и объявляли начало Века экологии, Марсиане – да, теперь у них было право так называться – в поту и грязи строили свой новый мир. Было наивно ожидать, что они строят его для удобно расположившихся на Земле “зрителей”. Ещё наивнее было не обращать внимания на растущую напряженность.
Первое массовое выступление за независимость Марса вспыхнуло всего через 30 лет после основания колонии. Ещё через 30 лет подобные выступления переросли в настоящую угрозу. А в 2197-м началась Первая война Марса за независимость.
Восстание было организовано нео-коммунистической партией Марса. Как ни странно, древние к тому моменту идеи оказались близки тысячам рабочих на красной планете. Самим определять свою жизнь. Стремиться к совершенствованию себя и мира вокруг, а не к бесцельному, сытому и тупому существованию до-граждан Земли. Сначала в движении доминировали гуманистические воззрения: Марсиане стремились к новому человеческому обществу, где править будет мысль, а не удовлетворение плотских нужд. Но после первой волны реакции, запретов и арестов инициативу перехватили приверженцы силовых мер и вооруженной борьбы.
Конечно же, и на Земле нашлись те, кто поддержал марсианское восстание. Видимо, это кроется в самой сути Человека: едва появляется шанс реализовать свои амбиции, как все прочие ценности становятся вторичными. Возможность создать собственную империю на Марсе расколола общество Земли. Закон о Новом порядке никто не отменял – миллиарды до-граждан даже ничего не заметили, но элита Земли вступила в эру нового противоборства.
Первая война за независимость была подавлена. Земля ввела войска, бунтовщиков арестовали, оружие изъяли. Но это была лишь первая вспышка – загасить пламя поднимающегося движения Земляне не смогли. Более двадцати лет ООН пыталась контролировать политику и экономику Марса, закрывать верфи, принуждать пользоваться только земными кораблями. На пропаганду идеи Единого Человечества были потрачены огромные ресурсы. Безуспешно.
Постоянно растущее сопротивление, приводящее к всё новым и новым жертвам, всё ещё можно можно было бы подавить силой. Но, разрываемая множеством внутренних течений, ООН на это не решилась. Слишком велики были бы потери для общества, которое не видело большой крови уже сто с лишним лет.
Ситуация разрешилась удивительным образом. Марсианин Соломон Эпштейн практически случайно пришёл к изобретению нового типа двигателя для космических кораблей. Обладая в тысячи раз большей эффективностью, новый двигатель сделал доступным для исследования и колонизации дальние рубежи Солнечной Системы. Будучи патриотом, Соломон посмертно подарил своё изобретение всем Марсианам.
Построенные на скорую руку, корабли с двигателем Эпштейна показывали такое преимущество над лучшими кораблями Земли, что становилось очевидно: эта технология изменит всё… И Земля не могла её упустить. В обмен на признание независимости Марса, как многие тогда считали – формальное, земные ученые получили полный доступ к исследованием Эпштейна.
Эти события имели два последствия. 
С одной стороны, на карте Человечества вновь появились два независимых лагеря. По историческим причинам недружественные друг другу, но чрезвычайно взаимо-зависимые. Пришлось извлечь из архивов и сдуть пыль с таких давно забытых понятий как “геополитика” и “гонка вооружений”.
С другой - обеим сторонам стал доступен дальний космос, а вместе с ним и пояс астероидов. Зачем добывать полезные ископаемые, выискивая их по крупице и тратя огромные средства на разработку, транспортировку и инфраструктуру на планете? Ведь теперь их можно просто находить в огромных глыбах, сканируя пространство спектроскопом, а затем разгонять в сторону Земли или Марса. Всех расходов – заселить несколько астероидов в ключевых точках Пояса.
И всё же, самым важным последствием “революции Эпштейна” стал “Исход”. Потрясающая простота и дешевизна двигателя сделали космос доступным каждому, у кого хватало духу пуститься в такое путешествие. Внезапно тысячи людей, конструируя корабли из старых транспортных баржей (а то и вовсе из бочек), ринулись в небо, опережая даже экспедиции, посланные в Пояс корпорациями.
Все те, кто не смог смириться ни с одним государственным строем, и составили основу самого молодого, уникального общества в составе Человечества – общества астероидян.
Крупные астероиды – Церера, Веста, Паллада, Европа, Эрос – быстро стали центрами новой цивилизации. Интересы Земли и Марса, военные и экономические, плотно перемешивались здесь с новой культурой – “варевом” из тысячи учений, верований и идей. Наверное, каждый, кто когда-то покинул поверхность одной из планет, принес сюда что-то свое.
Искатели приключений, жаждущие легкой наживы, мечтатели, строители собственных вероучений и империй, политические беженцы и просто путешественники смешивались с военными Земли и Марса, пилотами дальних транспортов и наёмными работниками корпораций.
Слишком далеко, чтобы попасть под полный контроль двух ключевых игроков человеческого мира. Слишком близко, чтобы не считаться с ними совсем. Слишком независимые по своему характеру – слишком зависимые из-за поставок ресурсов и обеспечения.
Тысячи маленьких станций и кораблей, снующих между астероидами. Бесконечные стычки из-за интересов, убеждений или банальной неприязни. Земному и Марсианскому правительствам, в спешке поделившим космос на зоны влияния, оставалось только притворяться, что они как-то контролируют весь этот рой.
Покорив новые пространства, люди строят и новое общество, опираясь на собственные принципы, исходящие из глубины их непокорной природы. Они сражаются за них, терпят лишения и рискуют, отрекаются от старого и видят надежду даже там, где её не может быть. Но именно так и только так совершается настоящая экспансия. Так и только так люди делают будущее настоящим, записывая, строчка за строчкой, историю нового человечества – Хомо Галактикус.

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Группа только с действиями:
  -- - Выводятся в правильном порядке
  -- - Действие без имени и с именем
  -- - Заблокированное действие и обычное

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "actions": ["%s", "%s", "%s", "%s"]}',
          v_test_prefix || 'group1',
          v_test_prefix || 'unnamed',
          v_test_prefix || 'named',
          v_test_prefix || 'unnamed_disabled',
          v_test_prefix || 'named_disabled')::jsonb);
    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s"]}',
          v_test_prefix || 'group2',
          v_test_prefix || 'next')::jsonb);

    insert into data.actions(code, function)
    values('do_nothing', 'test_project.do_nothing_action');

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.simple_actions_generator"'),
    (
      v_test_id,
      v_description_attribute_id,
      to_jsonb(text
'Ниже выведена группа, в которой нет атрибутов, только действия. Тест проверяет только отображение действий — все активные действия не имеют параметров, подтверждений, ничего не делают и возвращают do_nothing.

**Проверка 1:** Первым идёт действие без имени, затем с именем "Действие", затем снова действие без имени, а в самом конце — с именем "Заблокированное действие".
**Проверка 2:** Последние два действия заблокированы — отличаются внешне и не могут быть выполнены (например, кнопки не нажимаются).')
    ),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Действия после атрибутов

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'next', 'normal', 'full', true)
    returning id into v_next_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s"]}',
          v_test_prefix || 'group',
          v_test_prefix || 'next')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.simple_action_generator"'),
    (
      v_test_id,
      v_description_attribute_id,
      to_jsonb(text
'В этой группе есть и атрибут, и действие.

**Проверка:** Действие идёт после данного текста.')
    ),
    (
      v_test_id,
      v_next_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Действие и атрибут имеют одинаковый код

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_action_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'action', 'normal', 'full', true)
    returning id into v_action_attr_id;

    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "actions": ["%s"]}',
          v_test_prefix || 'group1',
          v_test_prefix || 'action')::jsonb);
    v_template_groups :=
      array_append(
        v_template_groups,
        format(
          '{"code": "%s", "attributes": ["%s"]}',
          v_test_prefix || 'group2',
          v_test_prefix || 'action')::jsonb);

    insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
    v_test_num := v_test_num + 1;
    insert into data.attribute_values(object_id, attribute_id, value) values
    (v_test_id, v_type_attribute_id, jsonb '"test"'),
    (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
    (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.object_action_generator"'),
    (
      v_test_id,
      v_description_attribute_id,
      to_jsonb(text
'В этом тесте есть атрибуты и действия с совпадающими кодами, они должны обрабатываться независимо.

**Проверка 1:** В следующей группе есть только действие.
**Проверка 2:** В последней группе есть только ссылка на следующий тест.')
    ),
    (
      v_test_id,
      v_action_attr_id,
      to_jsonb('[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Объект с заголовком

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_title_attribute_id, jsonb '"Jabberwocky"'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Атрибуты *title* и *subtitle* не входят в шаблон и должны обрабатываться клиентом особым образом.

**Проверка:** У данного объекта есть заголовок "Jabberwocky".

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Объект с заголовком и подзаголовком

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_title_attribute_id, jsonb '"Паллада"'),
  (v_test_id, v_subtitle_attribute_id, jsonb '"Ролевая игра"'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'**Проверка:** У данного объекта помимо заголовка есть ещё и подзаголовок "Ролевая игра".

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Объект с длинным заголовком и длинным подзаголовком

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_title_attribute_id, jsonb '"Сила притяжения: Паллада. Ролевая игра живого действия в жанре научной фантастики от мастерской группы White Star. Будет проходить 8-10 марта 2019 года на базе \"Спартанец\" под Новосибирском. Источники: сериал Expanse, книги Дж. Кори, Лема, Стругацких, Хайнлайна..."'),
  (v_test_id, v_subtitle_attribute_id, jsonb '"Это история о конфликте близкородственных культур, совсем недавно бывших единым целым. О том, как некогда единая цивилизация с иллюзией общего будущего оказывается разделённой на три различных вектора. Это игра о разных взглядах в Завтра и о корнях, которые всё еще прочно связывают все стороны конфликта. О попытках найти общий язык при острой потребности оставаться независимыми. И в каком-то смысле — это игра об отцах и детях. О праве новых поколений на самоопределение, развитие и свободу выбора собственного пути и об их надежде сохранить связь с истоками."'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Предполагается, что заголовок и подзаголовок — однострочники. Заголовок выводится крупным кеглем, а подзаголовок под ним — кеглем меньше. Возможно, даже другим шрифтом :)
Экраны телефонов у всех разные, так что даже относительно короткие тексты могут не войти. Такие тексты не нужно скроллировать по горизонтали или выводить в несколько строк, достаточно просто обрезать.

**Проверка:** У данного объекта и заголовок обрезаны.

[Продолжить](babcom:test' || v_test_num || ')')
  );

  -- Действие без подтверждения и параметров, params null

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  insert into data.actions(code, function, default_params)
  values(
    'next_action_with_null_params',
    'test_project.next_action_with_null_params',
    format('{"object_code": "%s"}', 'test' || v_test_num)::jsonb);
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_null_params_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Начинаем проверять обработку действий.
Атрибут *params* должен передаваться в неизменном виде. В действии ниже атрибут *params* равен *null*.

**Проверка 1:** Действие ниже перейдёт к следующему объекту.')
  );

  -- Действие без подтверждения и параметров, params - объект

  insert into data.actions(code, function)
  values('next_action_with_object_params', 'test_project.next_action_with_object_params');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_object_params_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Теперь атрибут *params* является объектом.

**Проверка 1:** Действие ниже перейдёт к следующему объекту.')
  );

  -- Действие без подтверждения и параметров, params - массив

  insert into data.actions(code, function)
  values('next_action_with_array_params', 'test_project.next_action_with_array_params');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_array_params_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'И, наконец, атрибут *params* является массивом.
Если этот тест и предыдущие два сработали, то считаем, что клиент честно передаёт *params* в неизменном виде, а не сделал специальную обработку null''а, объекта и массива :)

**Проверка 1:** Действие ниже перейдёт к следующему объекту.')
  );

  -- Действие с подтверждением

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_warning_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Действия с подтверждениями.

**Проверка 1:** По нажатию на кнопку ниже появляется диалог текстом "Вы действительно хотите перейти к следующему объекту?" и кнопками "ОК" и "Отмена".
**Проверка 2:** По нажатию на кнопку "Отмена" диалог закрывается и более ничего не происходит.
**Проверка 3:** По нажатию на кнопку "ОК" происходит переход к следующему тесту.')
  );

  -- Действие со строковым параметром

  insert into data.actions(code, function)
  values('next_action_with_text_user_param', 'test_project.next_action_with_text_user_param');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_text_user_param_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Действие со строковым параметром.

**Проверка 1:** По нажатию на кнопку ниже появляется форма с именем параметра "Текстовая строка", полем для ввода строки и кнопками "ОК" и "Отмена".
**Проверка 2:** По нажатию на кнопку "Отмена" форма закрывается и более ничего не происходит.
**Проверка 3:** В поле можно ввести только одну строку, Enter не срабатывает.
**Проверка 4:** По нажатию на кноку "ОК" происходит переход к следующему тесту.')
  );

  -- Действие с текстовым многострочным параметром

  insert into data.actions(code, function)
  values('next_action_with_multiline_user_param', 'test_project.next_action_with_multiline_user_param');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_multiline_user_param_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Действие с многострочным текстовым параметром.

**Проверка:** В поле можно ввести несколько строк текста.')
  );

  -- Действие, принимающее в качестве параметра целое число

  insert into data.actions(code, function)
  values('next_action_with_integer_user_param', 'test_project.next_action_with_integer_user_param');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_integer_user_param_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Действие, принимающее в качестве параметра целое число.
Здесь и далее: клиент может позволять вводить в поля значения, не удовлетворяющие ограничениям. Это может быть удобно, например, для вставки текста из буфера обмена и последующего редактирования значения.

**Проверка 1:** Кнопка "ОК" формы заблокирована и разблокируется только после ввода корректного целого числа.
**Проверка 2:** Как только поле ввода перестаёт содержать целое число, кнопка "ОК" снова блокируется.
**Проверка 3:** Пользователю сообщают, почему кнопка "ОК" заблокирована.')
  );

  -- Действие, принимающее в качестве параметра число с плавающей запятой

  insert into data.actions(code, function)
  values('next_action_with_double_user_param', 'test_project.next_action_with_double_user_param');

  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  v_test_num := v_test_num + 1;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (v_test_id, v_actions_function_attribute_id, jsonb '"test_project.next_action_with_double_user_param_generator"'),
  (v_test_id, v_title_attribute_id, format('"Тест %s"', v_test_num - 1)::jsonb),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Действие, принимающее в качестве параметра число с плавающей запятой.
Клиент вправе как разрешить, так и запретить ввод чисел в экспоненциальной записи.

**Проверка 1:** Кнопка "ОК" формы заблокирована и разблокируется только после ввода корректного числа (целого или с плавающей запятой).
**Проверка 2:** Как только поле ввода перестаёт содержать корректное число, кнопка "ОК" снова блокируется.
**Проверка 3:** Пользователю сообщают, почему кнопка "ОК" заблокирована.')
  );

  -- с ограничениями
  -- с min = max
  -- с длинной 0
  -- со значениями по умолчанию
  -- несколько параметров
  -- с параметрами и предупреждением

  -- todo действия
  -- todo и прочие тесты

  -- Финал!
  insert into data.objects(code) values('test' || v_test_num) returning id into v_test_id;
  insert into data.attribute_values(object_id, attribute_id, value) values
  (v_test_id, v_type_attribute_id, jsonb '"test"'),
  (v_test_id, v_is_visible_attribute_id, jsonb 'true'),
  (
    v_test_id,
    v_description_attribute_id,
    to_jsonb(text
'Пока что это все существующие тесты. Stay tuned!')
  );

  -- Заполним шаблон
  insert into data.params(code, value, description)
  values('template', jsonb_build_object('groups', to_jsonb(v_template_groups)), 'Шаблон');
end;
$$
language 'plpgsql';
