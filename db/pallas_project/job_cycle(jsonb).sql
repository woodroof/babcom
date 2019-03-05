-- drop function pallas_project.job_cycle(jsonb);

create or replace function pallas_project.job_cycle(in_params jsonb)
returns void
volatile
as
$$
declare
  v_system_money_attr_id integer := data.get_attribute_id('system_money');
  v_system_person_deposit_money_attr_id integer := data.get_attribute_id('system_person_deposit_money');
  v_system_person_coin_attr_id integer := data.get_attribute_id('system_person_coin');

  v_time timestamp with time zone;

  v_title_attr_id integer := data.get_attribute_id('title');
  v_redirect_att_id integer := data.get_attribute_id('redirect');
  v_money_attr_id integer := data.get_attribute_id('money');
  v_mini_description_attr_id integer := data.get_attribute_id('mini_description');
  v_is_visible_attr_id integer := data.get_attribute_id('is_visible');
  v_system_person_economy_type_attr_id integer := data.get_attribute_id('system_person_economy_type');
  v_system_person_notification_count_attr_id integer := data.get_attribute_id('system_person_notification_count');
  v_person_economy_type_attr_id integer := data.get_attribute_id('person_deposit_money');
  v_person_district_attr_id integer := data.get_attribute_id('person_district');
  v_person_coin_attr_id integer := data.get_attribute_id('person_coin');
  v_person_un_rating_attr_id integer := data.get_attribute_id('person_un_rating');
  v_system_org_economics_type_attr_id integer := data.get_attribute_id('system_org_economics_type');
  v_system_org_districts_control_attr_id integer := data.get_attribute_id('system_org_districts_control');
  v_system_org_budget_attr_id integer := data.get_attribute_id('system_org_budget');
  v_system_org_profit_attr_id integer := data.get_attribute_id('system_org_profit');
  v_system_org_tax_attr_id integer := data.get_attribute_id('system_org_tax');
  v_system_org_next_tax_attr_id integer := data.get_attribute_id('system_org_next_tax');
  v_org_tax_attr_id integer := data.get_attribute_id('org_tax');
  v_cycle_attr_id integer := data.get_attribute_id('cycle');
  v_status_shop_cycle_attr_id integer := data.get_attribute_id('status_shop_cycle');
  v_contract_status_attr_id integer := data.get_attribute_id('contract_status');
  v_contract_reward_attr_id integer := data.get_attribute_id('contract_reward');
  v_contract_org_attr_id integer := data.get_attribute_id('contract_org');
  v_content_attr_id integer := data.get_attribute_id('content');
  v_district_tax_attr_id integer := data.get_attribute_id('district_tax');
  v_district_control_attr_id integer := data.get_attribute_id('district_control');
  v_system_district_tax_coeff_attr_id integer := data.get_attribute_id('system_district_tax_coeff');

  v_system_person_life_support_status_attr_id integer := data.get_attribute_id('system_person_life_support_status');
  v_system_person_health_care_status_attr_id integer := data.get_attribute_id('system_person_health_care_status');
  v_system_person_recreation_status_attr_id integer := data.get_attribute_id('system_person_recreation_status');
  v_system_person_police_status_attr_id integer := data.get_attribute_id('system_person_police_status');
  v_system_person_administrative_services_status_attr_id integer := data.get_attribute_id('system_person_administrative_services_status');

  v_life_support_next_status_attr_id integer := data.get_attribute_id('life_support_next_status');
  v_health_care_next_status_attr_id integer := data.get_attribute_id('health_care_next_status');
  v_recreation_next_status_attr_id integer := data.get_attribute_id('recreation_next_status');
  v_police_next_status_attr_id integer := data.get_attribute_id('police_next_status');
  v_administrative_services_next_status_attr_id integer := data.get_attribute_id('administrative_services_next_status');

  v_life_support_status_attr_id integer := data.get_attribute_id('life_support_status');
  v_health_care_status_attr_id integer := data.get_attribute_id('health_care_status');
  v_recreation_status_attr_id integer := data.get_attribute_id('recreation_status');
  v_police_status_attr_id integer := data.get_attribute_id('police_status');
  v_administrative_services_status_attr_id integer := data.get_attribute_id('administrative_services_status');

  v_master_group_id integer := data.get_object_id('master');
  v_life_support_prices integer[] := data.get_integer_array_param('life_support_status_prices');
  v_life_support_price integer := v_life_support_prices[1];
  v_coin_price integer := data.get_integer_param('coin_price');
  v_new_cycle_num integer;

  v_district_taxes jsonb;
  v_district_ids jsonb;
  v_district_controls jsonb;
  v_district_tax_coeff jsonb;
  v_district_tax_total jsonb;

  v_person_id integer;
  v_org record;

  v_master_notifications jsonb := jsonb '[]';
  v_object_changes jsonb := jsonb '[]';
begin
  if not data.get_boolean_param('game_in_progress') then
    return;
  end if;

  -- Лочим всё, что точно будем менять
  perform
  from data.attribute_values
  where attribute_id in (v_system_money_attr_id, v_system_person_deposit_money_attr_id, v_system_person_coin_attr_id)
  for update;

  -- Используется только при создании персонажа, но на всякий обновим
  update data.params
  set value = to_jsonb(json.get_integer(value) + 1)
  where code = 'economic_cycle_number'
  returning json.get_integer(value) into v_new_cycle_num;

  -- Получим информацию о районах
  select
    jsonb_object_agg(o.code, data.get_raw_attribute_value_for_update(o.id, v_district_tax_attr_id)) tax_info,
    jsonb_object_agg(o.code, o.id) ids,
    jsonb_object_agg(o.code, data.get_raw_attribute_value_for_share(o.id, v_district_control_attr_id)) control,
    jsonb_object_agg(o.code, data.get_raw_attribute_value_for_share(o.id, v_system_district_tax_coeff_attr_id)) coeff,
    jsonb_object_agg(o.code, jsonb '0') tax_total
  into v_district_taxes, v_district_ids, v_district_controls, v_district_tax_coeff, v_district_tax_total
  from jsonb_array_elements(data.get_raw_attribute_value(data.get_object_id('districts'), v_content_attr_id)) d
  join data.objects o on
    o.code = json.get_string(d.value);

  v_time := clock_timestamp();

  -- Экономика для людей
  for v_person_id in
  (
    select object_id
    from data.object_objects
    where
      parent_object_id = data.get_object_id('all_person') and
      parent_object_id != object_id
  )
  loop
    declare
      v_person_code text := data.get_object_code(v_person_id);
      v_economy_type text := json.get_string_opt(data.get_raw_attribute_value_for_share(v_person_id, v_system_person_economy_type_attr_id), '');

      v_transactions jsonb := jsonb '[]';

      v_system_money bigint;
      v_system_person_deposit_money bigint;

      v_system_person_coin integer;
      v_coin_profit integer;

      v_person_district_code text;
      v_tax bigint;
      v_tax_coeff numeric;
      v_district_tax bigint;
      v_tax_sum bigint;
      v_org_tax_sum bigint;
      v_contract record;

      v_transactions_id integer;
      v_transactions_content jsonb;
      v_transaction record;

      v_notification_id integer;

      v_changes jsonb := jsonb '[]';
      v_remove_groups jsonb := jsonb '[]';
    begin
      if v_economy_type in ('asters', 'mcr') then
        v_system_money := json.get_bigint(data.get_raw_attribute_value(v_person_id, v_system_money_attr_id));

        if v_economy_type = 'asters' then
          -- Списываем остатки на инвестиционные счета
          if v_system_money > 0 then
            v_system_person_deposit_money := json.get_bigint(data.get_raw_attribute_value(v_person_id, v_system_person_deposit_money_attr_id)) + v_system_money;

            v_changes :=
              v_changes ||
              data.attribute_change2jsonb(v_system_person_deposit_money_attr_id, to_jsonb(v_system_person_deposit_money)) ||
              data.attribute_change2jsonb(v_person_economy_type_attr_id, to_jsonb(v_system_person_deposit_money), v_master_group_id) ||
              data.attribute_change2jsonb(v_person_economy_type_attr_id, to_jsonb(v_system_person_deposit_money), v_person_id);

            v_transactions :=
              v_transactions ||
              format(
                '{
                  "comment": "Спасибо, что выбрали наш инвестиционный фонд.\nГлава ИФ ООН Ашшурбанапал Ганди",
                  "value": %s,
                  "balance": 0
                }',
                -v_system_money)::jsonb;

            v_system_money := 0;
          end if;

          -- Получаем налог района проживания
          v_person_district_code := json.get_string(data.get_raw_attribute_value_for_share(v_person_id, v_person_district_attr_id));
          v_tax := json.get_integer(v_district_taxes, v_person_district_code);
          v_tax_coeff := json.get_number(v_district_tax_coeff, v_person_district_code);
          v_district_tax := json.get_bigint(v_district_tax_total, v_person_district_code);

          -- Начисляем зарплату по действующим контрактам
          for v_contract in
          (
            select
              o.code,
              json.get_bigint(data.get_raw_attribute_value(o.id, v_contract_reward_attr_id)) reward,
              json.get_string(data.get_raw_attribute_value(o.id, v_contract_org_attr_id)) org
            from jsonb_array_elements(data.get_raw_attribute_value_for_share(v_person_code || '_contracts', v_content_attr_id)) c
            join data.objects o on
              o.code = json.get_string(c.value)
            join data.attribute_values av on
              av.object_id = o.id and
              av.attribute_id = v_contract_status_attr_id and
              av.value_object_id is null and
              av.value in (jsonb '"active"', jsonb '"cancelled"')
          )
          loop
            v_tax_sum := ceil(v_tax * 0.01 * v_contract.reward);
            v_org_tax_sum := (v_tax_sum * v_tax_coeff)::bigint;
            v_district_tax := v_district_tax + v_org_tax_sum;
            v_system_money := v_system_money + v_contract.reward - v_tax_sum;

            v_transactions :=
              v_transactions ||
              format(
                '{
                  "comment": "Выплаты по контракту",
                  "value": %s,
                  "balance": %s,
                  %s
                  "second_object_code": "%s"
                }',
                v_contract.reward,
                v_system_money,
                (case when v_district_controls->v_person_district_code = jsonb 'null' then '' else format('"tax": %s,', v_tax_sum) end),
                v_contract.org)::jsonb;
          end loop;

          v_district_tax_total := jsonb_set(v_district_tax_total, array[v_person_district_code], to_jsonb(v_district_tax));
        end if;

        -- Покупаем статус жизнеобеспечения на следующий цикл
        v_system_money := v_system_money - v_life_support_price * v_coin_price;

        v_transactions :=
          v_transactions ||
          format(
            '{
              "comment": "Покупка бронзового статуса жизнеобеспечения",
              "value": %s,
              "balance": %s
            }',
            -v_life_support_price * v_coin_price,
            v_system_money)::jsonb;

        -- Сообщаем мастерам о тех, кто в минусе
        if v_system_money < 0 then
          v_master_notifications :=
            v_master_notifications ||
            to_jsonb(
              format(
                '[%s](babcom:%s) после покупки бронзового статуса жизнеобеспечения в минусе',
                json.get_string(data.get_raw_attribute_value(v_person_id, v_title_attr_id)),
                v_person_code));
        end if;

        -- Обновляем значение и заменяем видимые значения для мастеров и самого игрока
        v_changes :=
          v_changes ||
          data.attribute_change2jsonb(v_system_money_attr_id, to_jsonb(v_system_money)) ||
          data.attribute_change2jsonb(v_money_attr_id, to_jsonb(v_system_money), v_master_group_id) ||
          data.attribute_change2jsonb(v_money_attr_id, to_jsonb(v_system_money), v_person_id);

        v_transactions_id := data.get_object_id(v_person_code || '_transactions');
        v_transactions_content := data.get_raw_attribute_value_for_update(v_transactions_id, v_content_attr_id);

        for v_transaction in
        (
          select
            json.get_bigint(value, 'value') as value,
            json.get_bigint(value, 'balance') balance,
            json.get_string(value, 'comment') as comment,
            json.get_string_opt(value, 'second_object_code', null) second_code,
            json.get_bigint_opt(value, 'tax', null) tax
          from jsonb_array_elements(v_transactions)
        )
        loop
          declare
            v_transaction_id integer;
            v_description text;
          begin
            if v_transaction.value < 0 then
              v_description :=
                format(
                  E'%s\n%s\n%s\nБаланс: %s',
                  pp_utils.format_date(v_time),
                  pp_utils.format_money(v_transaction.value),
                  v_transaction.comment,
                  pp_utils.format_money(v_transaction.balance));
            else
              v_description :=
                format(
                  E'%s\n%s\n%s\nОтправитель: [%s](babcom:%s)%s\nБаланс: %s',
                  pp_utils.format_date(v_time),
                  '+' || pp_utils.format_money(v_transaction.value - coalesce(v_transaction.tax, 0)),
                  v_transaction.comment,
                  json.get_string(data.get_raw_attribute_value(data.get_object_id(v_transaction.second_code), v_title_attr_id)),
                  v_transaction.second_code,
                  (case when v_transaction.tax is not null then format(E'\nНалог: %s\nСумма перевода до налога: %s', pp_utils.format_money(v_transaction.tax), pp_utils.format_money(v_transaction.value)) else '' end),
                  pp_utils.format_money(v_transaction.balance));
            end if;

            v_transaction_id :=
              data.create_object(
                null,
                format(
                  '[
                    {"id": %s, "value": %s},
                    {"id": %s, "value": true, "value_object_id": %s}
                  ]',
                  v_mini_description_attr_id,
                  to_jsonb(v_description)::text,
                  v_is_visible_attr_id,
                  v_person_id)::jsonb,
                'transaction');

            v_transactions_content := to_jsonb(data.get_object_code(v_transaction_id)) || v_transactions_content;
          end;
        end loop;

        v_object_changes :=
          v_object_changes ||
          jsonb_build_object('id', v_transactions_id, 'changes', jsonb '[]' || data.attribute_change2jsonb(v_content_attr_id, v_transactions_content));

        v_notification_id :=
          data.create_object(
            null,
            format(
              '[
                {"id": %s, "value": true, "value_object_id": %s},
                {"id": %s, "value": "%s %s\n\n[История транзакций](babcom:%s)"},
                {"id": %s, "value": %s}
              ]',
              v_is_visible_attr_id,
              v_person_id,
              v_title_attr_id,
              'Начался цикл',
              v_new_cycle_num,
              v_person_code || '_transactions',
              v_redirect_att_id,
              v_transactions_id)::jsonb,
            'notification');
      elsif v_economy_type = 'un' then
        v_system_person_coin := json.get_integer(data.get_raw_attribute_value(v_person_id, v_system_person_coin_attr_id));

        -- Обнуляем токены, если их больше нуля
        if v_system_person_coin > 0 then
          v_system_person_coin := 0;
        end if;

        -- Начисляем новые коины
        v_coin_profit := pallas_project.un_rating_to_coins(json.get_integer(data.get_raw_attribute_value(v_person_id, v_person_un_rating_attr_id)));
        v_system_person_coin := v_system_person_coin + v_coin_profit;

        -- Покупаем статус жизнеобеспечения на следующий цикл
        v_system_person_coin := v_system_person_coin - v_life_support_price;

        -- Сообщаем мастерам о тех, кто в минусе
        if v_system_person_coin < 0 then
          v_master_notifications :=
            v_master_notifications ||
            to_jsonb(
              format(
                '[%s](babcom:%s) после покупки бронзового статуса жизнеобеспечения в минусе',
                json.get_string(data.get_raw_attribute_value(v_person_id, v_title_attr_id)),
                v_person_code));
        end if;

        -- Обновляем значение и заменяем видимые значения для мастеров и самого игрока
        v_changes :=
          v_changes ||
          data.attribute_change2jsonb(v_system_person_coin_attr_id, to_jsonb(v_system_person_coin)) ||
          data.attribute_change2jsonb(v_person_coin_attr_id, to_jsonb(v_system_person_coin), v_master_group_id) ||
          data.attribute_change2jsonb(v_person_coin_attr_id, to_jsonb(v_system_person_coin), v_person_id);
      end if;

      if v_economy_type in ('un', 'fixed', 'fixed_with_money') then
        v_notification_id :=
          data.create_object(
            null,
            format(
              '[
                {"id": %s, "value": true, "value_object_id": %s},
                {"id": %s, "value": "%s %s"}
              ]',
              v_is_visible_attr_id,
              v_person_id,
              v_title_attr_id,
              'Начался цикл',
              v_new_cycle_num)::jsonb,
            'notification');
      end if;

      if v_economy_type in ('asters', 'mcr', 'un') then
        -- Меняем текущие статусы на будущие и обнуляем будущие, а также проставляем money, person_coin и cycle
        declare
          v_next_statuses_id integer := data.get_object_id(v_person_code || '_next_statuses');

          v_life_support_next_status jsonb := data.get_raw_attribute_value_for_update(v_next_statuses_id, v_life_support_next_status_attr_id);
          v_health_care_next_status jsonb := data.get_raw_attribute_value_for_update(v_next_statuses_id, v_health_care_next_status_attr_id);
          v_recreation_next_status jsonb := data.get_raw_attribute_value_for_update(v_next_statuses_id, v_recreation_next_status_attr_id);
          v_police_next_status jsonb := data.get_raw_attribute_value_for_update(v_next_statuses_id, v_police_next_status_attr_id);
          v_administrative_services_next_status jsonb := data.get_raw_attribute_value_for_update(v_next_statuses_id, v_administrative_services_next_status_attr_id);
        begin
          v_object_changes :=
            v_object_changes ||
            jsonb_build_object(
              'id',
              data.get_object_id(v_person_code || '_life_support_status_page'),
              'changes',
              jsonb '[]' ||
              data.attribute_change2jsonb(v_cycle_attr_id, to_jsonb(v_new_cycle_num)) ||
              data.attribute_change2jsonb(v_life_support_status_attr_id, v_life_support_next_status));
          v_object_changes :=
            v_object_changes ||
            jsonb_build_object(
              'id',
              data.get_object_id(v_person_code || '_health_care_status_page'),
              'changes',
              jsonb '[]' ||
              data.attribute_change2jsonb(v_cycle_attr_id, to_jsonb(v_new_cycle_num)) ||
              data.attribute_change2jsonb(v_health_care_status_attr_id, v_health_care_next_status));
          v_object_changes :=
            v_object_changes ||
            jsonb_build_object(
              'id',
              data.get_object_id(v_person_code || '_recreation_status_page'),
              'changes',
              jsonb '[]' ||
              data.attribute_change2jsonb(v_cycle_attr_id, to_jsonb(v_new_cycle_num)) ||
              data.attribute_change2jsonb(v_recreation_status_attr_id, v_recreation_next_status));
          v_object_changes :=
            v_object_changes ||
            jsonb_build_object(
              'id',
              data.get_object_id(v_person_code || '_police_status_page'),
              'changes',
              jsonb '[]' ||
              data.attribute_change2jsonb(v_cycle_attr_id, to_jsonb(v_new_cycle_num)) ||
              data.attribute_change2jsonb(v_police_status_attr_id, v_police_next_status));
          v_object_changes :=
            v_object_changes ||
            jsonb_build_object(
              'id',
              data.get_object_id(v_person_code || '_administrative_services_status_page'),
              'changes',
              jsonb '[]' ||
              data.attribute_change2jsonb(v_cycle_attr_id, to_jsonb(v_new_cycle_num)) ||
              data.attribute_change2jsonb(v_administrative_services_status_attr_id, v_administrative_services_next_status));

          v_object_changes :=
            v_object_changes ||
            jsonb_build_object(
              'id',
              v_next_statuses_id,
              'changes',
              format(
                '[
                  {"id": %s, "value": %s},
                  {"id": %s, "value": 1},
                  {"id": %s, "value": 0},
                  {"id": %s, "value": 0},
                  {"id": %s, "value": 0},
                  {"id": %s, "value": 0},
                  {"id": %s, "value": %s}
                ]',
                v_status_shop_cycle_attr_id,
                v_new_cycle_num,
                v_life_support_next_status_attr_id,
                v_health_care_next_status_attr_id,
                v_recreation_next_status_attr_id,
                v_police_next_status_attr_id,
                v_administrative_services_next_status_attr_id,
                (case when v_economy_type = 'un' then v_person_coin_attr_id else v_money_attr_id end),
                (case when v_economy_type = 'un' then v_system_person_coin else v_system_money end))::jsonb);

          v_changes :=
            v_changes ||
            format(
              '[
                {"id": %s, "value": %s},
                {"id": %s, "value": %s},
                {"id": %s, "value": %s},
                {"id": %s, "value": %s},
                {"id": %s, "value": %s}
              ]',
              v_system_person_life_support_status_attr_id,
              json.get_integer(v_life_support_next_status),
              v_system_person_health_care_status_attr_id,
              json.get_integer(v_health_care_next_status),
              v_system_person_recreation_status_attr_id,
              json.get_integer(v_recreation_next_status),
              v_system_person_police_status_attr_id,
              json.get_integer(v_police_next_status),
              v_system_person_administrative_services_status_attr_id,
              json.get_integer(v_administrative_services_next_status))::jsonb;
        end;
      end if;

      if v_notification_id is not null then
        declare
          v_notifications_id integer := data.get_object_id(v_person_code || '_notifications');
          v_notifications_content jsonb := data.get_raw_attribute_value_for_update(v_notifications_id, v_content_attr_id);
        begin
          v_notifications_content := to_jsonb(data.get_object_code(v_notification_id)) || v_notifications_content;

          v_object_changes :=
            v_object_changes ||
            jsonb_build_object('id', v_notifications_id, 'changes', jsonb '[]' || data.attribute_change2jsonb(v_content_attr_id, v_notifications_content));

          v_changes := v_changes || data.attribute_change2jsonb(v_system_person_notification_count_attr_id, to_jsonb(jsonb_array_length(v_notifications_content)));
        end;
      end if;

      -- Исключаем из временных аудиторов и меняем организации
      declare
        v_my_organizations_id integer := data.get_object_id(v_person_code || '_my_organizations');
        v_my_organizations text[] := json.get_string_array(data.get_raw_attribute_value_for_update(v_my_organizations_id, v_content_attr_id));
        v_organization_code text;
        v_group_id integer;
        v_filtered_orgs text[] := array[]::text[];
      begin
        for v_organization_code in
        (
          select value
          from unnest(v_my_organizations) a(value)
        )
        loop
          v_group_id := data.get_object_id(v_organization_code || '_temporary_auditor');
          if pp_utils.is_in_group(v_person_id, v_group_id) then
            v_remove_groups := v_remove_groups || to_jsonb(v_group_id);
            v_filtered_orgs := array_append(v_filtered_orgs, v_organization_code);
          end if;
        end loop;

        if coalesce(array_length(v_filtered_orgs, 1), 0) != 0 then
          select array_agg(value)
          into v_my_organizations
          from unnest(v_my_organizations) a(value)
          where value not in (
            select value
            from unnest(v_filtered_orgs) b(value));

          v_object_changes :=
            v_object_changes ||
            jsonb_build_object('id', v_my_organizations_id, 'changes', jsonb '[]' || data.attribute_change2jsonb(v_content_attr_id, to_jsonb(coalesce(v_my_organizations, array[]::text[]))));
        end if;
      end;

      if v_changes != jsonb '[]' or v_remove_groups != jsonb '[]' then
        v_object_changes := v_object_changes || jsonb_build_object('id', v_person_id, 'changes', v_changes, 'remove_groups', v_remove_groups);
      end if;
    end;
  end loop;

  -- Экономика для организаций
  for v_org in
  (
    select o.id, o.code, json.get_string(av.value) economics_type
    from jsonb_array_elements(data.get_raw_attribute_value(data.get_object_id('organizations'), v_content_attr_id)) d
    join data.objects o on
      o.code = json.get_string(d.value)
    -- Пропускаем синонимы
    join data.attribute_values av on
      av.object_id = o.id and
      av.attribute_id = v_system_org_economics_type_attr_id and
      av.value_object_id is null
  )
  loop
    declare
      v_transactions jsonb := jsonb '[]';

      v_system_money bigint := data.get_raw_attribute_value_for_update(v_org.id, v_system_money_attr_id);
      v_control jsonb := data.get_raw_attribute_value_for_share(v_org.id, v_system_org_districts_control_attr_id);
      v_system_org_budget bigint;
      v_system_org_profit bigint;

      v_contracts_sum bigint := 0;
      v_contract record;

      v_transactions_id integer;
      v_transactions_content jsonb;
      v_transaction record;

      v_head_group_id integer := data.get_object_id(v_org.code || '_head');
      v_economist_group_id integer := data.get_object_id(v_org.code || '_economist');
      v_auditor_group_id integer := data.get_object_id(v_org.code || '_auditor');
      v_temporary_auditor_group_id integer := data.get_object_id(v_org.code || '_temporary_auditor');

      v_changes jsonb := jsonb '[]';
    begin
      -- Платим по действующим контрактам и меняем статус контрактов
      for v_contract in
      (
        select
          o.id id,
          o.code code,
          json.get_bigint(data.get_raw_attribute_value(o.id, v_contract_reward_attr_id)) reward,
          json.get_string(data.get_raw_attribute_value_for_update(o.id, v_contract_status_attr_id)) status
        from jsonb_array_elements(data.get_raw_attribute_value_for_share(v_org.code || '_contracts', v_content_attr_id)) c
        join data.objects o on
          o.code = json.get_string(c.value)
      )
      loop
        if v_contract.status in ('active', 'cancelled') then
          v_contracts_sum := v_contracts_sum + v_contract.reward;
        end if;

        if v_contract.status in ('confirmed', 'cancelled', 'suspended_cancelled') then
          v_object_changes :=
            v_object_changes ||
            jsonb_build_object(
              'id',
              v_contract.id,
              'changes',
              format(
                '{
                  "contract_status": "%s"
                }',
                (case when v_contract.status = 'confirmed' then 'active' else 'not_active' end))::jsonb);
        end if;
      end loop;

      if v_contracts_sum != 0 then
        v_system_money := v_system_money - v_contracts_sum;

        v_transactions :=
          v_transactions ||
          format(
            '{
              "comment": "Выплаты по контрактам",
              "value": %s,
              "balance": %s
            }',
            -v_contracts_sum,
            v_system_money)::jsonb;
      end if;

      -- Начисляем налоги и меняем налоговую ставку
      if v_control is not null then
        declare
          v_district text;
          v_system_org_next_tax integer := json.get_integer(data.get_raw_attribute_value_for_share(v_org.id, v_system_org_next_tax_attr_id));
          v_tax_sum bigint := 0;
        begin
          v_changes :=
            v_changes ||
            data.attribute_change2jsonb(v_system_org_tax_attr_id, to_jsonb(v_system_org_next_tax)) ||
            data.attribute_change2jsonb(v_org_tax_attr_id, to_jsonb(v_system_org_next_tax), v_master_group_id) ||
            data.attribute_change2jsonb(v_org_tax_attr_id, to_jsonb(v_system_org_next_tax), v_head_group_id) ||
            data.attribute_change2jsonb(v_org_tax_attr_id, to_jsonb(v_system_org_next_tax), v_economist_group_id);

          for v_district in
          (
            select json.get_string(value)
            from jsonb_array_elements(v_control)
          )
          loop
            v_tax_sum := v_tax_sum + json.get_bigint(v_district_tax_total, v_district);

            v_object_changes :=
              v_object_changes ||
              jsonb_build_object('id', json.get_integer(v_district_ids, v_district), 'changes', jsonb '[]' || data.attribute_change2jsonb(v_district_tax_attr_id, to_jsonb(v_system_org_next_tax)));
          end loop;

          if v_tax_sum != 0 then
            v_system_money := v_system_money + v_tax_sum;

            v_transactions :=
              v_transactions ||
              format(
                '{
                  "comment": "Начисление налогов",
                  "value": %s,
                  "balance": %s
                }',
                v_tax_sum,
                v_system_money)::jsonb;
          end if;
        end;
      end if;

      -- Безусловный доход
      if v_org.economics_type = 'profit' then
        v_system_org_profit := json.get_bigint(data.get_raw_attribute_value_for_share(v_org.id, v_system_org_profit_attr_id));

        v_system_money := v_system_money + v_system_org_profit;

        v_transactions :=
          v_transactions ||
          format(
            '{
              "comment": "Внешние поступления",
              "value": %s,
              "balance": %s
            }',
            v_system_org_profit,
            v_system_money)::jsonb;
      elsif v_org.economics_type = 'budget' then
        v_system_org_budget := json.get_bigint(data.get_raw_attribute_value_for_share(v_org.id, v_system_org_budget_attr_id));

        if v_system_money >= v_system_org_budget then
          v_master_notifications :=
            v_master_notifications ||
            to_jsonb(
              format(
                'У организации [%s](babcom:%s) на начало цикла денег больше бюджета, внешних поступлений нет!',
                json.get_string(data.get_raw_attribute_value(v_org.id, v_title_attr_id)),
                v_org.code));
        else
          if v_system_money < 0 then
            v_master_notifications :=
              v_master_notifications ||
              to_jsonb(
                format(
                  'Организация [%s](babcom:%s) на начало цикла после подсчёта расходов и доходов в минусе, бюджет на этот цикл увеличен!',
                  json.get_string(data.get_raw_attribute_value(v_org.id, v_title_attr_id)),
                  v_org.code));
          end if;

          v_system_org_budget := v_system_org_budget - v_system_money;

          v_system_money := v_system_money + v_system_org_budget;

          v_transactions :=
            v_transactions ||
            format(
              '{
                "comment": "Внешние поступления",
                "value": %s,
                "balance": %s
              }',
              v_system_org_budget,
              v_system_money)::jsonb;
        end if;
      end if;

      if v_system_money < 0 then
        v_master_notifications :=
          v_master_notifications ||
          to_jsonb(
            format(
              'Организация [%s](babcom:%s) на начало цикла после подсчёта расходов и доходов в минусе',
              json.get_string(data.get_raw_attribute_value(v_org.id, v_title_attr_id)),
              v_org.code));
      end if;

      -- Обновляем значение и заменяем видимые значения для мастеров и членов организации
      v_changes :=
        v_changes ||
        data.attribute_change2jsonb(v_system_money_attr_id, to_jsonb(v_system_money)) ||
        data.attribute_change2jsonb(v_money_attr_id, to_jsonb(v_system_money), v_master_group_id) ||
        data.attribute_change2jsonb(v_money_attr_id, to_jsonb(v_system_money), v_head_group_id) ||
        data.attribute_change2jsonb(v_money_attr_id, to_jsonb(v_system_money), v_economist_group_id) ||
        data.attribute_change2jsonb(v_money_attr_id, to_jsonb(v_system_money), v_auditor_group_id) ||
        data.attribute_change2jsonb(v_money_attr_id, to_jsonb(v_system_money), v_temporary_auditor_group_id);

      if v_transactions != jsonb '[]' then
        v_transactions_id := data.get_object_id(v_org.code || '_transactions');
        v_transactions_content := data.get_raw_attribute_value_for_update(v_transactions_id, v_content_attr_id);

        for v_transaction in
        (
          select
            json.get_bigint(value, 'value') as value,
            json.get_bigint(value, 'balance') balance,
            json.get_string(value, 'comment') as comment
          from jsonb_array_elements(v_transactions)
        )
        loop
          declare
            v_transaction_id integer;
            v_description text;
          begin
            v_description :=
              format(
                E'%s\n%s\n%s\nБаланс: %s',
                pp_utils.format_date(v_time),
                (case when v_transaction.value < 0 then '' else '+' end) || pp_utils.format_money(v_transaction.value),
                v_transaction.comment,
                pp_utils.format_money(v_transaction.balance));

            v_transaction_id :=
              data.create_object(
                null,
                format(
                  '[
                    {"id": %s, "value": %s},
                    {"id": %s, "value": true, "value_object_id": %s},
                    {"id": %s, "value": true, "value_object_id": %s},
                    {"id": %s, "value": true, "value_object_id": %s},
                    {"id": %s, "value": true, "value_object_id": %s}
                  ]',
                  v_mini_description_attr_id,
                  to_jsonb(v_description)::text,
                  v_is_visible_attr_id,
                  v_head_group_id,
                  v_is_visible_attr_id,
                  v_economist_group_id,
                  v_is_visible_attr_id,
                  v_auditor_group_id,
                  v_is_visible_attr_id,
                  v_temporary_auditor_group_id)::jsonb,
                'transaction');

            v_transactions_content := to_jsonb(data.get_object_code(v_transaction_id)) || v_transactions_content;
          end;
        end loop;

        v_object_changes :=
          v_object_changes ||
          jsonb_build_object('id', v_transactions_id, 'changes', jsonb '[]' || data.attribute_change2jsonb(v_content_attr_id, v_transactions_content));
      end if;

      if v_changes != jsonb '[]' then
        v_object_changes := v_object_changes || jsonb_build_object('id', v_org.id, 'changes', v_changes);
      end if;
    end;
  end loop;

  perform data.process_diffs_and_notify(data.change_objects(v_object_changes));

  declare
    v_message text := 'Начался цикл ' || v_new_cycle_num;
    v_notification text;
  begin
    if v_master_notifications != jsonb '[]' then
      v_message := v_message || E'\n';

      for v_notification in
      (
        select json.get_string(value)
        from jsonb_array_elements(v_master_notifications)
      )
      loop
        v_message := v_message || E'\n' || v_notification;
      end loop;
    end if;

    perform pallas_project.send_to_master_chat(v_message);
  end;
end;
$$
language plpgsql;
