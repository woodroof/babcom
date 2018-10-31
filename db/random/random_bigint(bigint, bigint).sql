-- drop function random.random_bigint(bigint, bigint);

create or replace function random.random_bigint(in_min_value bigint, in_max_value bigint)
returns bigint
volatile
as
$$

-- Возвращает случайное число от in_min_value до in_max_value включительно
declare
  v_random_double double precision := random();
begin
  assert in_min_value is not null;
  assert in_max_value is not null;
  assert in_min_value <= in_max_value is not null;

  if in_min_value = in_max_value then
    return in_min_value;
  end if;

  return floor(in_min_value + v_random_double * (in_max_value - in_min_value + 1));
end;

$$
language 'plpgsql';
