-- drop function pallas_project.create_transaction(integer, text, bigint, bigint, bigint, integer, integer);

create or replace function pallas_project.create_transaction(in_object_id integer, in_comment text, in_value bigint, in_balance bigint, in_tax bigint, in_second_object_id integer, in_actor_id integer)
returns void
volatile
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
  v_description text;
  v_transaction_id integer;
  v_second_object_title text;
  v_second_object_code text;
begin
  assert in_comment is not null;
  assert in_value is not null;
  assert in_balance is not null;
  assert in_tax is null or in_tax >= 0 and in_tax <= abs(in_value);

  if in_second_object_id is not null then
    v_second_object_title := json.get_string_opt(data.get_attribute_value(in_second_object_id, 'title', in_object_id), null);
    if v_second_object_title is not null then
      v_second_object_code := data.get_object_code(in_second_object_id);
    end if;
  end if;

  if in_value < 0 then
    v_description :=
      format(
        E'%s\n%s\n%s%s%s\nБаланс: %s',
        pp_utils.format_date(clock_timestamp()),
        pp_utils.format_money(in_value),
        in_comment,
        (case when v_second_object_title is not null then format(E'\nПолучатель: [%s](babcom:%s)', v_second_object_title, v_second_object_code) else '' end),
        (case when in_tax is not null then format(E'\nНалог: %s\nСумма перевода после налога: %s', pp_utils.format_money(in_tax), pp_utils.format_money(abs(in_value) - in_tax)) else '' end),
        pp_utils.format_money(in_balance));
  else
    v_description :=
      format(
        E'%s\n%s\n%s%s%s\nБаланс: %s',
        pp_utils.format_date(clock_timestamp()),
        '+' || pp_utils.format_money(in_value - coalesce(in_tax, 0)),
        in_comment,
        (case when v_second_object_title is not null then format(E'\nОтправитель: [%s](babcom:%s)', v_second_object_title, v_second_object_code) else '' end),
        (case when in_tax is not null then format(E'\nНалог: %s\nСумма перевода до налога: %s', pp_utils.format_money(in_tax), pp_utils.format_money(in_value)) else '' end),
        pp_utils.format_money(in_balance));
  end if;

  v_transaction_id :=
    data.create_object(
      null,
      format(
        '[
          {"code": "is_visible", "value": true, "value_object_id": %s},
          {"code": "mini_description", "value": %s}
        ]',
        in_object_id,
        to_jsonb(v_description)::text)::jsonb,
      'transaction');

  perform pp_utils.list_prepend_and_notify(
    data.get_object_id(v_object_code || '_transactions'),
    data.get_object_code(v_transaction_id),
    null,
    in_actor_id);
end;
$$
language plpgsql;
