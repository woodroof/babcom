-- drop function pallas_project.vd_not_found_description(integer, jsonb, integer);

create or replace function pallas_project.vd_not_found_description(in_attribute_id integer, in_value jsonb, in_actor_id integer)
returns text
immutable
as
$$
declare
  v_random integer := random.random_integer(1, 11);
begin
  if v_random = 1 then
    return 'Это не те дроиды, которых вы ищете';
  elsif v_random = 2 then
    return 'Эта страница заблокирована по решению Комитета общественной безопасности Марсианской Республики Конгресса';
  elsif v_random = 3 then
    return 'Истина где-то рядом';
  elsif v_random = 4 then
    return 'Большой брат следит за тобой';
  elsif v_random = 5 then
    return 'Добро пожаловать в реальный мир';
  elsif v_random = 6 then
    return 'Не все ли равно, о чем спрашивать, если ответа все равно не получишь, правда?';
  elsif v_random = 7 then
    return 'Мы будем править всей этой землёй, и мы назовём её... Эта Земля.';
  elsif v_random = 8 then
    return 'Ты не пройдёшь!';
  elsif v_random = 9 then
    return 'Принцесса в другом замке!';
  elsif v_random = 10 then
    return 'Нет никакого торта';
  end if;

  return 'Меньше значит больше';
end;
$$
language plpgsql;
