-- Function: test.run_all_tests()

-- DROP FUNCTION test.run_all_tests();

CREATE OR REPLACE FUNCTION test.run_all_tests()
  RETURNS text AS
$BODY$
-- Тесты запускаются в пустой базе
-- Ищутся и запускаются функции *_test.*, возвращающие void и не имеющие входных параметров
-- Тест считается успешно выполненным, если он не выбросил исключения
declare
  v_test_case record;
  v_test record;

  v_test_cases_count integer;
  v_tests_count integer;
  v_total_tests_count integer;
  v_failed_count integer := 0;

  v_current_test_case integer := 1;
  v_current_test integer;

  v_void_id integer;

  v_exception_message text;
  v_exception_call_stack text;
begin
  -- Определяем количество тест-кейсов
  select count(1)
  into v_test_cases_count
  from pg_namespace
  where nspname like '%_test';

  -- Определяем количество тестов
  select count(1)
  into v_total_tests_count
  from pg_proc
  where
    pronamespace =
      (
        select oid
        from pg_namespace
        where nspname like '%_test'
      ) and
    prorettype =
      (
        select oid
        from pg_type
        where typname = 'void'
      ) and
    pronargs = 0;

  -- Определяем id типа void для пропуска функций, возвращающих какое-то значение
  select oid
  into v_void_id
  from pg_type
  where typname = 'void';

  for v_test_case in
  (
    select oid as id, nspname as name
    from pg_namespace
    where nspname like '%_test'
    order by name
  )
  loop
    raise notice 'Running test case % of %: %', v_current_test_case, v_test_cases_count, v_test_case.name;
    v_current_test_case := v_current_test_case + 1;

    v_current_test := 1;

    -- Считаем количество тестов в тест-кейсе
    select count(1)
    into v_tests_count
    from pg_proc
    where
      pronamespace = v_test_case.id and
      prorettype = v_void_id and
      pronargs = 0;

    for v_test in
    (
      select
        proname as name,
        prorettype as type,
        pronargs as arg_count,
        provolatile as volative
      from pg_proc
      where pronamespace = v_test_case.id
      order by name
    )
    loop
      if v_test.type != v_void_id then
        raise notice 'Skipping function % due to non-void return value', v_test_case.name || '.' || v_test.name;
        continue;
      end if;

      if v_test.arg_count != 0 then
        raise notice 'Skipping function % due to more than zero arguments', v_test_case.name || '.' || v_test.name;
        continue;
      end if;

      raise notice 'Running test % of %: %', v_current_test, v_tests_count, v_test.name;
      v_current_test := v_current_test + 1;

      begin
        begin
          -- Выполняем процедуру
          execute 'select ' || v_test_case.name || '.' || v_test.name || '()';
        exception when others then
          -- Выводим сообщение об ошибке
          get stacked diagnostics
            v_exception_message = message_text,
            v_exception_call_stack = pg_exception_context;

          raise notice 'Test failed!';
          raise notice E'Error: %\nCall stack:\n%', v_exception_message, v_exception_call_stack;

          v_failed_count := v_failed_count + 1;
        end;

        if v_test.volative = 'v' then
          -- Откатываем изменения теста
          raise exception 'Rollback';
        end if;
      exception when others then
      end;
    end loop;
  end loop;

  if v_failed_count = 0 then
    raise notice 'Successfully completed % tests in % test cases', v_total_tests_count, v_test_cases_count;
    return '[OK]';
  else
    raise notice 'Failed % out of % tests in % test cases', v_failed_count, v_total_tests_count, v_test_cases_count;
    return '[FAILED]';
  end if;
end;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
