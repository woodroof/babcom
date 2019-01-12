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
  v_template_groups := array_append(v_template_groups, jsonb '{"code": "common", "attributes": ["description"]}');

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

Проверка 3: После запуска приложения пользователю не показывали какие-то диалоги.
Приложение само запросило с сервера список акторов, само выбрало в качестве активного первый (в конце концов, в большинстве случаев список будет состоять из одного пункта, а мы не хотим заставлять пользователя делать лишние действия) и само же открыло объект этого выбранного актора.

Проверка 4: Приложение выводит только заголовок, подзаголовок и атрибуты, присутствующие в шаблоне. В данном конкретном случае нигде не выведен тип объекта ("test").
Считаем, что приложение честно не выводит атрибуты, отсутствующие в шаблоне и не являющиеся заголовком или подзаголовком, и верим, что атрибут с кодом "type" не обрабатывается особым образом :)

Проверка 5: Ниже есть ссылка с именем "Продолжить", ведущая на следующий тест. Приложение по нажатию на эту ссылку должно перейти к следующему объекту.

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
'Проверка: Эта строка находится в новом атрибуте. Она должна быть отделена от предыдущей, причём желательно, чтобы это разделение было визуально отлично от обычного начала новой строки.

[Продолжить](babcom:test' || v_test_num || ')')
    );
  end;

  -- Вывод чисел

  declare
    v_test_prefix text := 'test' || v_test_num || '_';
    v_description_attr_id integer;
    v_int_attr_id integer;
    v_float_attr_id integer;
    v_next_attr_id integer;
  begin
    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'description', 'normal', 'full', true)
    returning id into v_description_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'integer', 'normal', 'full', true)
    returning id into v_int_attr_id;

    insert into data.attributes(code, type, card_type, can_be_overridden)
    values(v_test_prefix || 'float', 'normal', 'full', true)
    returning id into v_float_attr_id;

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
          v_test_prefix || 'float',
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

Проверка: Ниже выведены числа -42 и 0.0314159265 (именно так, а не в экспоненциальной записи!).')
    ),
    (v_test_id, v_int_attr_id, jsonb '-42'),
    (v_test_id, v_float_attr_id, jsonb '0.0314159265'),
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
    v_float_attr_id integer;
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
    values(v_test_prefix || 'float', 'test_project.test_value_description_function', 'normal', 'full', true)
    returning id into v_float_attr_id;

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
          v_test_prefix || 'float',
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

Проверка: Ниже выведены строки "минус сорок два", "π / 100" и "∫x dx = ½x² + C".')
    ),
    (v_test_id, v_int_attr_id, jsonb '-42'),
    (v_test_id, v_float_attr_id, jsonb '0.0314159265'),
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

Проверка: Ниже выведена жирная строка "один" и наклонная строка "два".')
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
'Проверка: Эта строка находится в новой группе. Должно быть явно видно, где закончилась предыдущая группа и началась новая.

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
'Проверка: У этой группы есть имя. Мы должны видеть текст "Короткое имя группы".

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

Проверка 1: Ниже есть ещё одна группа с именем "Тестовые данные".
Проверка 2: Первый атрибут в группе имеет имя "Атрибут 1" и не имеет значения и описания значения.
Проверка 3: Второй атрибут имеет длинное имя, которое не влезает в одну строку, начинается с "Атрибут с очень" и не имеет значения и описания значения.
Проверка 4: Третий атрибут имеет имя "Атрибут 3" и значение "100".
Проверка 5: Четвёртый атрибут имеет имя, начинающееся с "Ещё один атрибут" и также не влезающее в одну строку. Атрибут имеет довольно длинное описание значения, начинающееся с "Lorem ipsum".
Проверка 6: Слово ipsum должно быть жирным.
Проверка 7: Все атрибуты идут именно в указанном порядке.')
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

  -- todo

  -- Заполним шаблон
  insert into data.params(code, value, description)
  values ('template', jsonb_build_object('groups', to_jsonb(v_template_groups)), 'Шаблон');
end;
$$
language 'plpgsql';
