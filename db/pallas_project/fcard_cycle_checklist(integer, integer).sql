-- drop function pallas_project.fcard_cycle_checklist(integer, integer);

create or replace function pallas_project.fcard_cycle_checklist(object_id integer, actor_id integer)
returns void
volatile
as
$$
declare
  v_description text :=
'Уведомление в мастерский чат приходит за 15 минут до наступления цикла. Это время даётся на то, чтобы:
1. [Изменить](babcom:prices), если нужно, стоимость коина и стоимости в коинах статусов.
2. Изменить, если нужно, потребление ресурсов секторами (руками в базе!).
3. Пройтись по гражданам ООН (кроме экономиста и начальника шахты) и вручную изменить им рейтинг.
4. Пройтись по организациям с бюджетом и, если нужно, изменить им бюджет.
5. Пройтись по организациям с безусловным доходом и, если нужно, изменить им доход.
6. Начиная с конца второго цикла - списать UN$500 с организации [Тариель](babcom:org_tariel).

Граждане ООН:
%s

Организации с бюджетом:
%s

Организации с безусловным доходом:
%s

После наступления нового цикла:
1. Отреагировать на сообщение в мастерский чат про успехи администрации и поменять рейтинг и количество доступных коинов [экономиста](babcom:0d07f15b-2952-409b-b22e-4042cf70acc6) (см. справку в самом низу этой страницы).
2. Отреагировать на сообщение в мастерский чат про успехи Де Бирс и поменять рейтинг и количество доступных коинов [директора](babcom:784e4126-8dd7-41a3-a916-0fdc53a31ce2).
3. Если меняли стоимости коинов или статусов, как-то донести это до игроков.
4. Как-то отреагировать на сообщения в мастерский чат о том, что кто-то в минусе.
5. Гражданам ООН, у которых заметно изменился рейтинг, от лица мастерских персонажей написать какое-то сообщение.
6. Проверить, что картель перечислял нужную сумму в головную организацию. Написать им о планах на новый цикл.
7. Написать Де Бирс о планах на новый цикл.
8. Подумать, нужно ли написать что-то администрации, клинике, Akira SC.
9. Написать СВП о новых закупочных ценах на алмазы.
10. Посмотреть, отреагировал ли [мормон](babcom:ac1b23d0-ba5f-4042-85d5-880a66254803) на запросы о помощи, изменить его влияние. Написать новые запросы, если нужно.
11. Подумать, нужно ли поменять коэффициент при покупке ресурсов (на начало игры - 0.15).
12. В начале пятого цикла — проверить, купила ли в прошлом цикле организация [Тариель](babcom:org_tariel) лицензию у администрации за UN$1000.

Справка по рейтингам и статусам:
<100 10
<200 29
<300 34
<400 50
<500 60
<600 70
>599 80';
  v_un_citizens text;
  v_bugdet_orgs text;
  v_profit_orgs text;
begin
  select string_agg(value, E'\n')
  into v_un_citizens
  from (
    select format('[%s](babcom:%s)', json.get_string(av.value), o.code) as value
    from data.object_objects oo
    join data.objects o on
      o.id = oo.object_id
    join data.attribute_values av on
      av.object_id = o.id and
      av.attribute_id = data.get_attribute_id('title') and
      av.value_object_id is null
    where
      oo.parent_object_id = data.get_object_id('un') and
      oo.object_id != oo.parent_object_id
    order by value) v;

  select string_agg(value, E'\n')
  into v_bugdet_orgs
  from (
    select format('[%s](babcom:%s)', json.get_string(av.value), o.code) as value
    from data.object_objects oo
    join data.objects o on
      o.id = oo.object_id
    join data.attribute_values av on
      av.object_id = o.id and
      av.attribute_id = data.get_attribute_id('title') and
      av.value_object_id is null
    where
      oo.parent_object_id = data.get_object_id('budget_orgs') and
      oo.object_id != oo.parent_object_id) v;

  select string_agg(value, E'\n')
  into v_profit_orgs
  from (
    select format('[%s](babcom:%s)', json.get_string(av.value), o.code) as value
    from data.object_objects oo
    join data.objects o on
      o.id = oo.object_id
    join data.attribute_values av on
      av.object_id = o.id and
      av.attribute_id = data.get_attribute_id('title') and
      av.value_object_id is null
    where
      oo.parent_object_id = data.get_object_id('profit_orgs') and
      oo.object_id != oo.parent_object_id) v;

  perform data.change_object_and_notify(
    object_id,
    jsonb_build_object(
      'description',
      format(v_description, coalesce(v_un_citizens, ''), coalesce(v_bugdet_orgs, ''), coalesce(v_profit_orgs, ''))));
end;
$$
language plpgsql;
