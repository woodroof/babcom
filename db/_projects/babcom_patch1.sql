update data.params
set value = 
jsonb '
{
  "groups": [
    {
      "attributes": ["balance"]
    },
    {
      "attributes": ["transaction_time", "transaction_sum", "balance_rest", "transaction_from", "transaction_to", "transaction_description"]
    },
    {
      "actions": ["generate_money", "state_money_transfer", "transfer", "send_mail", "send_mail_from_future", "send_notification", "show_transaction_list", "create_personal_document"]
    },
    {
      "attributes": ["person_race", "person_state", "person_psi_scale", "person_job_position"]
    },
    {
      "attributes": ["person_biography"]
    },
    {
      "attributes": ["person_salary"]
    },
    {
      "attributes": ["political_influence"]
    },
    {
      "attributes": ["mail_type", "mail_send_time", "mail_title", "mail_author", "mail_receivers"],
      "actions": ["reply", "reply_all", "delete_mail"]
    },
    {
      "attributes": ["mail_body"]
    },
    {
      "attributes": ["news_time", "news_media", "news_title"],
      "actions": ["edit_news", "delete_news"]
    },
    {
      "attributes": ["state_tax"],
      "actions": ["change_state_tax"]
    },
    {
      "attributes": ["corporation_state", "corporation_capitalization", "corporation_sectors", "dividend_vote"],
      "actions": ["set_dividend_vote"]
    },
    {
      "attributes": ["corporation_members"],
      "actions": ["create_percent_deal"]
    },
    {
      "actions": ["create_deal"]
    },
    {
      "attributes": ["corporation_deals", "corporation_draft_deals", "corporation_canceled_deals"]
    },
    {
      "attributes": ["document_title", "document_time", "document_author"],
      "actions": ["share_document", "edit_med_document", "edit_document", "delete_document", "delete_library_document", "delete_personal_document"]
    },
    {
      "attributes": ["med_document_patient"]
    },
    {
      "attributes": ["deal_time", "deal_cancel_time", "deal_status", "deal_sector", "asset_name", "asset_cost", "asset_amortization", "deal_income"],
      "actions": ["edit_deal", "delete_deal", "check_deal", "confirm_deal", "cancel_deal"]
    },
    {
      "attributes": ["percent_deal_time", "percent_deal_status", "percent_deal_corporation", "percent_deal_sender", "percent_deal_receiver", "percent_deal_percent", "percent_deal_sum"],
      "actions": ["edit_percent_deal", "confirm_percent_deal", "cancel_percent_deal"]
    },
    {
      "attributes": ["deal_participant1"],
      "actions": ["edit_deal_member1", "delete_deal_member1"]
    },
    {
      "attributes": ["deal_participant2"],
      "actions": ["edit_deal_member2", "delete_deal_member2"]
    },
    {
      "attributes": ["deal_participant3"],
      "actions": ["edit_deal_member3", "delete_deal_member3"]
    },
    {
      "attributes": ["deal_participant4"],
      "actions": ["edit_deal_member4", "delete_deal_member4"]
    },
    {
      "attributes": ["deal_participant5"],
      "actions": ["edit_deal_member5", "delete_deal_member5"]
    },
    {
      "attributes": ["deal_participant6"],
      "actions": ["edit_deal_member6", "delete_deal_member6"]
    },
    {
      "attributes": ["deal_participant7"],
      "actions": ["edit_deal_member7", "delete_deal_member7"]
    },
    {
      "attributes": ["deal_participant8"],
      "actions": ["edit_deal_member8", "delete_deal_member8"]
    },
    {
      "attributes": ["deal_participant9"],
      "actions": ["edit_deal_member9", "delete_deal_member9"]
    },
    {
      "attributes": ["deal_participant10"],
      "actions": ["edit_deal_member10", "delete_deal_member10"]
    },
    {
      "actions": ["add_deal_member"]
    },
    {
      "attributes": ["description", "content"]
    },
    {
      "actions": ["login"]
    },
    {
      "attributes": ["sector_volume", "sector_volume_changes"],
      "actions": ["change_sector_volume"]
    },
    {
      "attributes": ["market_last_time"],
      "actions": ["calc_money"]
    },
    {
      "attributes": ["vote_status", "vote_theme", "vote_history"],
      "actions": ["start_vote", "stop_vote", "vote_yes", "vote_no"]
    },
    {
      "attributes": ["agreement_accept_cost", "agreement_cancel_cost", "agreement_status", "agreement_type", "agreement_signers"],
      "actions": ["create_agreement", "confirm_agreement", "delete_agreement", "cancel_agreement", "reject_agreement"]
    }
  ]
}
'
where code = 'template';

insert into data.objects(code) values
('agreement_types'),
('draft_agreements'),
('done_agreements'),
('deleted_agreements'),
('canceled_agreements');

insert into data.objects(code)
select 'agreement_type' || o.value from generate_series(1, 20) o(value);

CREATE OR REPLACE FUNCTION attribute_value_description_functions.agreement_status(
    in_user_object_id integer,
    in_attribute_id integer,
    in_value jsonb)
  RETURNS text AS
$BODY$
declare
  v_text_value text := json.get_string(in_value);
begin
  case when v_text_value = 'draft' then
    return 'На рассмотрении';
  when v_text_value = 'done' then
    return 'Принято';
  when v_text_value = 'canceled' then
    return 'Расторгнуто';
  when v_text_value = 'deleted' then
    return 'Удалено';
  else
    return '-';
  end case;

  return null;
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;
  
insert into data.attributes(code, name, type, value_description_function) values
('agreement_accept_cost', 'Стоимость принятия соглашения', 'NORMAL', null),
('agreement_cancel_cost', 'Стоимость расторжения соглашения', 'NORMAL', null),
('agreement_income', 'Доход за заключение соглашения', 'SYSTEM', null),
('agreement_status', 'Статус соглашения', 'NORMAL', 'agreement_status'),
('agreement_author', 'Автор соглашения', 'SYSTEM', null),
('agreement_type', 'Тип соглашения', 'NORMAL', 'code'),
('agreement_signers', 'Список подписавшихся', 'NORMAL', 'codes'),
('agreement_types', 'Типы соглашений', 'INVISIBLE', null),
('system_agreement_time', 'Дата изменения соглашения', 'SYSTEM', null)
;

insert into data.attribute_value_change_functions(attribute_id, function, params) values
(data.get_attribute_id('type'), 'string_value_to_object', jsonb '{"params": {"agreement_type": "agreement_types"}}'),
(data.get_attribute_id('type'), 'string_value_to_attribute', jsonb '{"params": {"agreement_type": {"object_code": "agreement_types", "attribute_code": "agreement_types"}}}'),
(data.get_attribute_id('agreement_status'), 'string_value_to_object', jsonb '{"params": {"done": "done_agreements", "draft": "draft_agreements", "canceled": "canceled_agreements"}}');

update data.attribute_value_fill_functions
set params = '
  {
    "blocks": [
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "news_hub"}, {"attribute_code": "type", "attribute_value": "media"}],
        "function": "fill_content",
        "params": {"placeholder": "Новостей нет", "sort_attribute_code": "system_news_time", "sort_type": "desc", "output": [{"type": "attribute", "data": "news_time"}, {"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "library_category"}],
        "function": "fill_content",
        "params": {"placeholder": "Документов нет", "sort_attribute_code": "name", "sort_type": "asc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "group"}],
        "function": "fill_if_object_attribute",
        "params": {
          "blocks": [
            {
              "conditions": [{"attribute_code": "system_meta", "attribute_value": true}],
              "function": "fill_content",
              "params": {"sort_attribute_code": "name", "sort_type": "asc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
            }
          ]
        }
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "mailbox"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "name", "sort_type": "asc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "system_mail_folder_type", "attribute_value": "inbox"}],
        "function": "fill_user_content_from_user_value_attribute",
        "params": {"source_attribute_code": "inbox", "placeholder": "Писем нет", "sort_attribute_code": "system_mail_send_time", "sort_type": "desc", "output": [{"type": "attribute", "data": "mail_send_time"}, {"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "system_mail_folder_type", "attribute_value": "outbox"}],
        "function": "fill_user_content_from_user_value_attribute",
        "params": {"source_attribute_code": "outbox", "placeholder": "Писем нет", "sort_attribute_code": "system_mail_send_time", "sort_type": "desc", "output": [{"type": "attribute", "data": "mail_send_time"}, {"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "transactions"}],
        "function": "fill_user_content_from_attribute",
        "params": {"placeholder": "Транзакций нет", "source_attribute_code": "system_value", "sort_type": "desc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "personal_library"}],
        "function": "fill_personal_library"
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "person_draft_percent_deals"}],
        "function": "fill_user_content_from_attribute",
        "params": {"placeholder": "Предложений продажи акций нет", "source_attribute_code": "percent_deals", "sort_type": "desc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "med_library"}],
        "function": "fill_user_content",
        "params": {"placeholder": "Отчётов нет", "sort_attribute_code": "system_document_time", "sort_type": "desc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "research_library"}],
        "function": "fill_user_content",
        "params": {"placeholder": "Отчётов нет", "sort_attribute_code": "system_document_time", "sort_type": "desc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "crew_library"}],
        "function": "fill_user_content",
        "params": {"placeholder": "Отчётов нет", "sort_attribute_code": "system_document_time", "sort_type": "desc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "corporations"}, {"attribute_code": "type", "attribute_value": "market"}, {"attribute_code": "type", "attribute_value": "states"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "name", "sort_type": "asc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "normal_deals"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_deal_time", "sort_type": "desc", "output": [{"type": "attribute", "data": "deal_time"}, {"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "canceled_deals"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_deal_time", "sort_type": "desc", "output": [{"type": "attribute", "data": "deal_cancel_time"}, {"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "draft_deals"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_deal_time", "sort_type": "desc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "percent_deals"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "name", "sort_type": "asc", "output": [{"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "done_percent_deals"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_percent_deal_time", "sort_type": "desc", "output": [{"type": "attribute", "data": "percent_deal_time"}, {"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "canceled_percent_deals"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_percent_deal_time", "sort_type": "desc", "output": [{"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "draft_percent_deals"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_percent_deal_time", "sort_type": "desc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "transaction_list"}],
        "function": "fill_transaction_list"
      },
	  {
        "conditions": [{"attribute_code": "type", "attribute_value": "done_agreements"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_agreement_time", "sort_type": "desc", "output": [{"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "canceled_agreements"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_agreement_time", "sort_type": "desc", "output": [{"type": "string", "data": " <a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      },
      {
        "conditions": [{"attribute_code": "type", "attribute_value": "draft_agreements"}],
        "function": "fill_content",
        "params": {"sort_attribute_code": "system_agreement_time", "sort_type": "desc", "output": [{"type": "string", "data": "<a href=\"babcom:"}, {"type": "code"}, {"type": "string", "data": "\">"}, {"type": "attribute", "data": "name"}, {"type": "string", "data": "</a>"}]}
      }
    ]
  }'
   where attribute_id = data.get_attribute_id('content') and function = 'fill_if_object_attribute';
  
  select data.set_attribute_value(data.get_object_id('politicians'), data.get_attribute_id('system_is_visible'), null, jsonb 'true');
  
select data.set_attribute_value(data.get_object_id('draft_agreements'), data.get_attribute_id('system_meta'), data.get_object_id('masters'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('draft_agreements'), data.get_attribute_id('system_meta'), data.get_object_id('politicians'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('draft_agreements'), data.get_attribute_id('system_is_visible'), data.get_object_id('masters'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('draft_agreements'), data.get_attribute_id('system_is_visible'), data.get_object_id('politicians'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('draft_agreements'), data.get_attribute_id('type'), null, jsonb '"draft_agreements"');
select data.set_attribute_value(data.get_object_id('draft_agreements'), data.get_attribute_id('name'), null, jsonb '"Соглашения на рассмотрении"');

select data.set_attribute_value(data.get_object_id('done_agreements'), data.get_attribute_id('system_meta'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('done_agreements'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('done_agreements'), data.get_attribute_id('type'), null, jsonb '"done_agreements"');
select data.set_attribute_value(data.get_object_id('done_agreements'), data.get_attribute_id('name'), null, jsonb '"Принятые соглашения"');

select data.set_attribute_value(data.get_object_id('canceled_agreements'), data.get_attribute_id('system_meta'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('canceled_agreements'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('canceled_agreements'), data.get_attribute_id('type'), null, jsonb '"canceled_agreements"');
select data.set_attribute_value(data.get_object_id('canceled_agreements'), data.get_attribute_id('name'), null, jsonb '"Расторгнутые соглашения"');

select data.set_attribute_value(data.get_object_id('agreement_types'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_types'), data.get_attribute_id('type'), null, jsonb '"agreement_types"');
select data.set_attribute_value(data.get_object_id('agreement_types'), data.get_attribute_id('name'), null, jsonb '"Типы соглашений"');

select data.set_attribute_value(data.get_object_id('agreement_type1'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type1'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type1'), data.get_attribute_id('name'), null, jsonb '"1.1.Об объявлении войны"');
select data.set_attribute_value(data.get_object_id('agreement_type1'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(1000000));
select data.set_attribute_value(data.get_object_id('agreement_type1'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(100000));
select data.set_attribute_value(data.get_object_id('agreement_type1'), data.get_attribute_id('agreement_income'), null, to_jsonb(1000200));

select data.set_attribute_value(data.get_object_id('agreement_type2'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type2'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type2'), data.get_attribute_id('name'), null, jsonb '"1.2.О режиме содержания и обмене военнопленными"');
select data.set_attribute_value(data.get_object_id('agreement_type2'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(1000000));
select data.set_attribute_value(data.get_object_id('agreement_type2'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(100000));
select data.set_attribute_value(data.get_object_id('agreement_type2'), data.get_attribute_id('agreement_income'), null, to_jsonb(1000200));

select data.set_attribute_value(data.get_object_id('agreement_type3'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type3'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type3'), data.get_attribute_id('name'), null, jsonb '"1.3.О прекращении огня"');
select data.set_attribute_value(data.get_object_id('agreement_type3'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(1000000));
select data.set_attribute_value(data.get_object_id('agreement_type3'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(100000));
select data.set_attribute_value(data.get_object_id('agreement_type3'), data.get_attribute_id('agreement_income'), null, to_jsonb(1000200));

select data.set_attribute_value(data.get_object_id('agreement_type4'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type4'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type4'), data.get_attribute_id('name'), null, jsonb '"1.4.О капитуляции и контрибуции"');
select data.set_attribute_value(data.get_object_id('agreement_type4'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(1000000));
select data.set_attribute_value(data.get_object_id('agreement_type4'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(100000));
select data.set_attribute_value(data.get_object_id('agreement_type4'), data.get_attribute_id('agreement_income'), null, to_jsonb(1000200));

select data.set_attribute_value(data.get_object_id('agreement_type5'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type5'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type5'), data.get_attribute_id('name'), null, jsonb '"2.1.О разграничении сфер влияния"');
select data.set_attribute_value(data.get_object_id('agreement_type5'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(800000));
select data.set_attribute_value(data.get_object_id('agreement_type5'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(200000));
select data.set_attribute_value(data.get_object_id('agreement_type5'), data.get_attribute_id('agreement_income'), null, to_jsonb(1000000));

select data.set_attribute_value(data.get_object_id('agreement_type6'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type6'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type6'), data.get_attribute_id('name'), null, jsonb '"2.2.Об установлении дипломатических отношений"');
select data.set_attribute_value(data.get_object_id('agreement_type6'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(800000));
select data.set_attribute_value(data.get_object_id('agreement_type6'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(200000));
select data.set_attribute_value(data.get_object_id('agreement_type6'), data.get_attribute_id('agreement_income'), null, to_jsonb(1000000));

select data.set_attribute_value(data.get_object_id('agreement_type7'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type7'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type7'), data.get_attribute_id('name'), null, jsonb '"2.3.О ненападении"');
select data.set_attribute_value(data.get_object_id('agreement_type7'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(800000));
select data.set_attribute_value(data.get_object_id('agreement_type7'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(200000));
select data.set_attribute_value(data.get_object_id('agreement_type7'), data.get_attribute_id('agreement_income'), null, to_jsonb(1000000));

select data.set_attribute_value(data.get_object_id('agreement_type8'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type8'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type8'), data.get_attribute_id('name'), null, jsonb '"2.4.О культурных и гуманитарных контактах"');
select data.set_attribute_value(data.get_object_id('agreement_type8'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(800000));
select data.set_attribute_value(data.get_object_id('agreement_type8'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(200000));
select data.set_attribute_value(data.get_object_id('agreement_type8'), data.get_attribute_id('agreement_income'), null, to_jsonb(1000000));

select data.set_attribute_value(data.get_object_id('agreement_type9'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type9'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type9'), data.get_attribute_id('name'), null, jsonb '"3.1.О пошлинах"');
select data.set_attribute_value(data.get_object_id('agreement_type9'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(500000));
select data.set_attribute_value(data.get_object_id('agreement_type9'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(500000));
select data.set_attribute_value(data.get_object_id('agreement_type9'), data.get_attribute_id('agreement_income'), null, to_jsonb(800000));

select data.set_attribute_value(data.get_object_id('agreement_type10'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type10'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type10'), data.get_attribute_id('name'), null, jsonb '"3.2.Об экстрадиции преступников"');
select data.set_attribute_value(data.get_object_id('agreement_type10'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(500000));
select data.set_attribute_value(data.get_object_id('agreement_type10'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(500000));
select data.set_attribute_value(data.get_object_id('agreement_type10'), data.get_attribute_id('agreement_income'), null, to_jsonb(800000));

select data.set_attribute_value(data.get_object_id('agreement_type11'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type11'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type11'), data.get_attribute_id('name'), null, jsonb '"3.3.О культурном обмене"');
select data.set_attribute_value(data.get_object_id('agreement_type11'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(500000));
select data.set_attribute_value(data.get_object_id('agreement_type11'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(500000));
select data.set_attribute_value(data.get_object_id('agreement_type11'), data.get_attribute_id('agreement_income'), null, to_jsonb(800000));

select data.set_attribute_value(data.get_object_id('agreement_type12'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type12'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type12'), data.get_attribute_id('name'), null, jsonb '"3.4.Об оборонительном союзе"');
select data.set_attribute_value(data.get_object_id('agreement_type12'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(500000));
select data.set_attribute_value(data.get_object_id('agreement_type12'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(500000));
select data.set_attribute_value(data.get_object_id('agreement_type12'), data.get_attribute_id('agreement_income'), null, to_jsonb(800000));

select data.set_attribute_value(data.get_object_id('agreement_type13'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type13'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type13'), data.get_attribute_id('name'), null, jsonb '"3.5.О визовом режиме"');
select data.set_attribute_value(data.get_object_id('agreement_type13'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(500000));
select data.set_attribute_value(data.get_object_id('agreement_type13'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(500000));
select data.set_attribute_value(data.get_object_id('agreement_type13'), data.get_attribute_id('agreement_income'), null, to_jsonb(800000));

select data.set_attribute_value(data.get_object_id('agreement_type14'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type14'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type14'), data.get_attribute_id('name'), null, jsonb '"4.1.О партнёрстве"');
select data.set_attribute_value(data.get_object_id('agreement_type14'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(200000));
select data.set_attribute_value(data.get_object_id('agreement_type14'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(800000));
select data.set_attribute_value(data.get_object_id('agreement_type14'), data.get_attribute_id('agreement_income'), null, to_jsonb(600000));

select data.set_attribute_value(data.get_object_id('agreement_type15'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type15'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type15'), data.get_attribute_id('name'), null, jsonb '"4.2.О научно-техническом сотрудничестве"');
select data.set_attribute_value(data.get_object_id('agreement_type15'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(200000));
select data.set_attribute_value(data.get_object_id('agreement_type15'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(800000));
select data.set_attribute_value(data.get_object_id('agreement_type15'), data.get_attribute_id('agreement_income'), null, to_jsonb(600000));

select data.set_attribute_value(data.get_object_id('agreement_type16'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type16'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type16'), data.get_attribute_id('name'), null, jsonb '"4.3.О военном альянсе"');
select data.set_attribute_value(data.get_object_id('agreement_type16'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(200000));
select data.set_attribute_value(data.get_object_id('agreement_type16'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(800000));
select data.set_attribute_value(data.get_object_id('agreement_type16'), data.get_attribute_id('agreement_income'), null, to_jsonb(600000));

select data.set_attribute_value(data.get_object_id('agreement_type17'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type17'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type17'), data.get_attribute_id('name'), null, jsonb '"4.4.О беспошлинной торговле"');
select data.set_attribute_value(data.get_object_id('agreement_type17'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(200000));
select data.set_attribute_value(data.get_object_id('agreement_type17'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(800000));
select data.set_attribute_value(data.get_object_id('agreement_type17'), data.get_attribute_id('agreement_income'), null, to_jsonb(600000));

select data.set_attribute_value(data.get_object_id('agreement_type18'), data.get_attribute_id('system_is_visible'), data.get_object_id('persons'), jsonb 'true');
select data.set_attribute_value(data.get_object_id('agreement_type18'), data.get_attribute_id('type'), null, jsonb '"agreement_type"');
select data.set_attribute_value(data.get_object_id('agreement_type18'), data.get_attribute_id('name'), null, jsonb '"4.5.О режиме свободного посещения"');
select data.set_attribute_value(data.get_object_id('agreement_type18'), data.get_attribute_id('agreement_accept_cost'), null, to_jsonb(200000));
select data.set_attribute_value(data.get_object_id('agreement_type18'), data.get_attribute_id('agreement_cancel_cost'), null, to_jsonb(800000));
select data.set_attribute_value(data.get_object_id('agreement_type18'), data.get_attribute_id('agreement_income'), null, to_jsonb(600000));

 -- Действие для создания соглашения
CREATE OR REPLACE FUNCTION action_generators.create_agreement(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_is_in_group integer; 
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_user_code text := data.get_object_code(v_user_object_id);
  v_object_id integer := json.get_integer(in_params, 'object_id');
begin
   -- Показываем только для политиков и для мастера и когда голосование началось
  if (not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_politician')), false)
  and not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_master')), false)) then
     return null;
   end if;
  
  return jsonb_build_object(
    'create_agreement',
    jsonb_build_object(
      'code', 'create_agreement',
      'name', 'Создать соглашение',
      'type', 'politics.agreement',
	  'user_params', 
       jsonb_build_array(
	     jsonb_build_object(
            'code', 'name',
            'type', 'string',
            'description', 'Заголовок соглашения',
             'data', jsonb_build_object('min_length', 1),
            'min_value_count', 1,
            'max_value_count', 1),
         jsonb_build_object(
            'code', 'description',
            'type', 'string',
            'description', 'Текст соглашения',
            'data', jsonb_build_object('min_length', 1, 'multiline', true),
            'min_value_count', 1,
            'max_value_count', 1),
         jsonb_build_object(
            'code', 'signers',
            'type', 'objects',
            'description', 'Список подписавшихся',
            'data', jsonb_build_object('object_code', 'politicians', 'attribute_code', 'politicians'),
            'min_value_count', 1,
            'max_value_count', 100),
         jsonb_build_object(
            'code', 'agreement_type',
            'type', 'objects',
            'description', 'Тип соглашения',
            'data', jsonb_build_object('object_code', 'agreement_types', 'attribute_code', 'agreement_types'),
            'min_value_count', 1,
            'max_value_count', 1)
      )));
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
  
CREATE OR REPLACE FUNCTION actions.create_agreement(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_agreement_id integer;
  v_agreement_code text;
  v_name text := json.get_string(in_user_params, 'name');
  v_description text := json.get_string(in_user_params, 'description');
  v_signers jsonb := '[]'::jsonb || in_user_params->'signers';
  v_agreement_type text := json.get_string(in_user_params, 'agreement_type');
  v_agreement_type_id integer := data.get_object_id(v_agreement_type);
  v_agreement_accept_cost integer;
  v_agreement_cancel_cost integer;
  v_agreement_accept_cost_attribute_id integer := data.get_attribute_id('agreement_accept_cost');
  v_agreement_cancel_cost_attribute_id integer := data.get_attribute_id('agreement_cancel_cost');
begin
  insert into data.objects(id) values(default)
  returning id, code into v_agreement_id, v_agreement_code;

  v_agreement_accept_cost := json.get_integer(data.get_raw_attribute_value(v_agreement_type_id, v_agreement_accept_cost_attribute_id, null));
  v_agreement_cancel_cost := json.get_integer(data.get_raw_attribute_value(v_agreement_type_id, v_agreement_cancel_cost_attribute_id, null));
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('system_is_visible'), null, jsonb 'true', in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('type'), null, jsonb '"agreement"', in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('name'), null, to_jsonb(v_name), in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('agreement_author'), null, to_jsonb(in_user_object_id), in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('description'), null, to_jsonb(v_description), in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('agreement_signers'), null, v_signers, in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('system_agreement_time'), null, to_jsonb(utils.system_time()), in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('agreement_status'), null, jsonb '"draft"', in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('agreement_type'), null, to_jsonb(v_agreement_type), in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, v_agreement_accept_cost_attribute_id, null, to_jsonb(v_agreement_accept_cost), in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, v_agreement_cancel_cost_attribute_id, null, to_jsonb(v_agreement_cancel_cost), in_user_object_id);

  return api_utils.get_objects(in_client,
			  in_user_object_id,
			  jsonb_build_object(
			    'object_codes', jsonb_build_array(v_agreement_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

  -- Действие для утверждения соглашений
CREATE OR REPLACE FUNCTION action_generators.confirm_agreement(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_is_in_group integer; 
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
begin
   -- Показываем только для мастера, и если она ещё черновик 
  if not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_master')), false) or 
     json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('agreement_status')),'~') <> 'draft' then
     return null;
   end if;
  
  return jsonb_build_object(
    'confirm_agreement',
    jsonb_build_object(
      'code', 'confirm_agreement',
      'name', 'Подтвердить соглашение',
      'type', 'politics.agreement',
      'warning', 'Проверьте, что стороны имеют нужный уровень отношений для заключения такого договора!',
      'params', jsonb_build_object('agreement_code', data.get_object_code(v_object_id)))
      );
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

CREATE OR REPLACE FUNCTION actions.confirm_agreement(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_agreement_code text := json.get_string(in_params, 'agreement_code');
  v_agreement_id integer := data.get_object_id(v_agreement_code);
  v_agreement_name text;
  v_agreement_signers jsonb;
  v_author_id integer;
  v_balance integer;
  v_agreement_accept_cost integer;
  v_agreement_income integer;
  v_agreement_type text;

  v_system_balance_attribute_id integer := data.get_attribute_id('system_balance');
  v_name_attribute_id integer := data.get_attribute_id('name');
  v_politics record;
  
  v_ret_val api.result;
begin
  v_ret_val := api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_agreement_code),
			    'get_actions', true,
			    'get_templates', true));
  if json.get_opt_string(data.get_attribute_value(in_user_object_id,
					          v_agreement_id, 
					          data.get_attribute_id('agreement_status')),'~') <> 'draft' then
    v_ret_val.data := v_ret_val.data::jsonb || jsonb '{"message": "Статус соглашения изменился!"}';
    return v_ret_val;
   end if;

  
  v_author_id := json.get_opt_integer(data.get_raw_attribute_value(v_agreement_id, data.get_attribute_id('agreement_author'), null));
  v_agreement_accept_cost := json.get_opt_integer(data.get_raw_attribute_value(v_agreement_id, data.get_attribute_id('agreement_accept_cost'), null), 0);
  v_agreement_type := json.get_string(data.get_raw_attribute_value(v_agreement_id, data.get_attribute_id('agreement_type'), null));
  v_agreement_income := json.get_opt_integer(data.get_raw_attribute_value(data.get_object_id(v_agreement_type), data.get_attribute_id('agreement_income'), null), 0);
  v_agreement_name := json.get_opt_string(data.get_raw_attribute_value(v_agreement_id, v_name_attribute_id, null), '-');
  v_agreement_signers := '[]'::jsonb || data.get_raw_attribute_value(v_agreement_id, data.get_attribute_id('agreement_signers'), null);

  if v_agreement_accept_cost > 0 then
  -- проверить, что у всех хватает денег на оплату соглашения
  for v_politics in (select distinct value from jsonb_array_elements_text(v_agreement_signers)) loop
    v_balance := json.get_opt_integer(data.get_attribute_value_for_share(data.get_object_id(v_politics.value), v_system_balance_attribute_id, null));
  
    if v_balance < v_agreement_accept_cost then 
        v_ret_val.data := v_ret_val.data::jsonb || jsonb '{"message": "На балансе '|| json.get_string(data.get_raw_attribute_value(data.get_object_id(v_politics.value),v_name_attribute_id, null)) || 'недостаточно средств для оплаты соглашения"}';
        return v_ret_val;
    end if;
   end loop;
   for v_politics in (select distinct value from jsonb_array_elements_text(v_agreement_signers)) loop
       perform actions.transfer_to_null(in_client, data.get_object_id(v_politics.value), null, jsonb_build_object('receiver', 'assembly', 'description', 'Оплата за подтверждение соглашения ' || v_agreement_name, 'sum', v_agreement_accept_cost));
   end loop;
  end if;
  if v_agreement_income > 0 then
    for v_politics in (select distinct value from jsonb_array_elements_text(v_agreement_signers)) loop
       perform actions.generate_money(in_client, data.get_object_id('assembly'), null, jsonb_build_object('receiver', v_politics.value, 'description', 'Доход за подтверждение соглашения ' || v_agreement_name, 'sum', v_agreement_income));
     end loop; 
  end if;
   
  -- поменять статус сделки и даты
  perform data.set_attribute_value_if_changed(v_agreement_id, data.get_attribute_id('agreement_status'), null, jsonb '"done"', in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('system_agreement_time'), null, to_jsonb(utils.system_time()), in_user_object_id);

  
  return api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_agreement_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

  -- Действие для отклонения соглашения
CREATE OR REPLACE FUNCTION action_generators.reject_agreement(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_is_in_group integer; 
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
begin
   -- Показываем только для мастера, и если она ещё черновик 
  if not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_master')), false) or 
     json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('agreement_status')),'~') <> 'draft' then
     return null;
   end if;
  
  return jsonb_build_object(
    'reject_agreement',
    jsonb_build_object(
      'code', 'reject_agreement',
      'name', 'Отклонить соглашение',
      'type', 'politics.agreement',
      'warning', 'Вы уверены, что хотите отклонить соглашение?',
      'params', jsonb_build_object('agreement_code', data.get_object_code(v_object_id)))
      );
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

CREATE OR REPLACE FUNCTION actions.reject_agreement(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_agreement_code text := json.get_string(in_params, 'agreement_code');
  v_agreement_id integer := data.get_object_id(v_agreement_code);
  
  v_ret_val api.result;
begin
  v_ret_val := api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_agreement_code),
			    'get_actions', true,
			    'get_templates', true));
  if json.get_opt_string(data.get_attribute_value(in_user_object_id,
					          v_agreement_id, 
					          data.get_attribute_id('agreement_status')),'~') <> 'draft' then
    v_ret_val.data := v_ret_val.data::jsonb || jsonb '{"message": "Статус соглашения изменился!"}';
    return v_ret_val;
   end if;

  -- поменять статус соглашения даты
  perform data.set_attribute_value_if_changed(v_agreement_id, data.get_attribute_id('agreement_status'), null, jsonb '"deleted"', in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('system_agreement_time'), null, to_jsonb(utils.system_time()), in_user_object_id);

  
  return api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_agreement_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

CREATE OR REPLACE FUNCTION action_generators.cancel_agreement(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
begin
   -- Показываем только для мастера и для участников соглашения, и если оно подтверждено
  if (not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_master')), false)
      and not(data.get_raw_attribute_value(v_object_id, data.get_attribute_id('agreement_signers'), null)?data.get_object_code(v_user_object_id))) or 
     json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('agreement_status')),'~') <> 'done' then
     return null;
   end if;
  
  return jsonb_build_object(
    'cancel_agreement',
    jsonb_build_object(
      'code', 'cancel_agreement',
      'name', 'Расторгнуть',
      'type', 'politics.agreement',
      'warning', 'Вы уверены, что хотите расторгнуть соглашение?',
      'params', jsonb_build_object('agreement_code', data.get_object_code(v_object_id)))
      );
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

CREATE OR REPLACE FUNCTION actions.cancel_agreement(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_agreement_code text := json.get_string(in_params, 'agreement_code');
  v_agreement_id integer := data.get_object_id(v_agreement_code);
  v_agreement_name text;
  v_balance integer;
  v_agreement_cancel_cost integer;

  v_system_balance_attribute_id integer := data.get_attribute_id('system_balance');
  
  v_ret_val api.result;
begin
  v_ret_val := api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_agreement_code),
			    'get_actions', true,
			    'get_templates', true));
  if json.get_opt_string(data.get_attribute_value(in_user_object_id,
					          v_agreement_id, 
					          data.get_attribute_id('agreement_status')),'~') <> 'done' then
    v_ret_val.data := v_ret_val.data::jsonb || jsonb '{"message": "Статус соглашения изменился!"}';
    return v_ret_val;
   end if;

  v_agreement_cancel_cost := json.get_opt_integer(data.get_raw_attribute_value(v_agreement_id, data.get_attribute_id('agreement_cancel_cost'), null), 0);
  v_agreement_name := json.get_opt_string(data.get_raw_attribute_value(v_agreement_id, data.get_attribute_id('name'), null), '-');
  
  if v_agreement_cancel_cost > 0 then
  -- проверить, что у юзера хватает денег на оплату расторжения соглашения
    v_balance := json.get_opt_integer(data.get_attribute_value_for_share(in_user_object_id, v_system_balance_attribute_id, null));
  
    if v_balance < v_agreement_cancel_cost then 
        v_ret_val.data := v_ret_val.data::jsonb || jsonb '{"message": "На вашем счету недостаточно средств для оплаты расторжения соглашения"}';
        return v_ret_val;
    end if;
    perform actions.transfer_to_null(in_client, in_user_object_id, null, jsonb_build_object('receiver', 'assembly', 'description', 'Оплата за расторжение соглашения ' || v_agreement_name, 'sum', v_agreement_cancel_cost));
  end if;
 
  -- поменять статус сделки и даты
  perform data.set_attribute_value_if_changed(v_agreement_id, data.get_attribute_id('agreement_status'), null, jsonb '"canceled"', in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('system_agreement_time'), null, to_jsonb(utils.system_time()), in_user_object_id);

  
  return api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_agreement_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

  -- Действие для удаления соглашения
CREATE OR REPLACE FUNCTION action_generators.delete_agreement(
    in_params in jsonb)
  RETURNS jsonb AS
$BODY$
declare 
  v_user_object_id integer := json.get_integer(in_params, 'user_object_id');
  v_object_id integer := json.get_integer(in_params, 'object_id');
begin
   -- Показываем только для мастера и {для участников соглашения, если оно не подтверждено}
  if (not json.get_opt_boolean(data.get_attribute_value(v_user_object_id,
					       v_user_object_id, 
					       data.get_attribute_id('system_master')), false)
      and (not(data.get_raw_attribute_value(v_object_id, data.get_attribute_id('agreement_signers'), null)?data.get_object_code(v_user_object_id)) or 
     json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('agreement_status')),'~') <> 'draft'))
     or json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('agreement_status')),'~') = 'deleted' then
     return null;
   end if;
  
  return jsonb_build_object(
    'delete_agreement',
    jsonb_build_object(
      'code', 'delete_agreement',
      'name', 'Удалить',
      'type', 'politics.agreement',
      'warning', 'Вы уверены, что хотите удалить соглашение?',
      'params', jsonb_build_object('agreement_code', data.get_object_code(v_object_id), 'agreement_status', json.get_opt_string(data.get_attribute_value(v_user_object_id,
					          v_object_id, 
					          data.get_attribute_id('agreement_status')),'~')))
      );
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

CREATE OR REPLACE FUNCTION actions.delete_agreement(
    in_client text,
    in_user_object_id integer,
    in_params jsonb,
    in_user_params jsonb)
  RETURNS api.result AS
$BODY$
declare
  v_agreement_code text := json.get_string(in_params, 'agreement_code');
  v_agreement_id integer := data.get_object_id(v_agreement_code);
  v_agreement_status text := json.get_string(in_params, 'agreement_status');
  
  v_ret_val api.result;
begin
  v_ret_val := api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_agreement_code),
			    'get_actions', true,
			    'get_templates', true));
  if json.get_opt_string(data.get_attribute_value(in_user_object_id,
					          v_agreement_id, 
					          data.get_attribute_id('agreement_status')),'~') <> v_agreement_status then
    v_ret_val.data := v_ret_val.data::jsonb || jsonb '{"message": "Статус соглашения изменился!"}';
    return v_ret_val;
   end if;

  -- поменять статус соглашения даты
  perform data.set_attribute_value_if_changed(v_agreement_id, data.get_attribute_id('agreement_status'), null, jsonb '"deleted"', in_user_object_id);
  perform data.set_attribute_value(v_agreement_id, data.get_attribute_id('system_agreement_time'), null, to_jsonb(utils.system_time()), in_user_object_id);

  
  return api_utils.get_objects(in_client,
				     in_user_object_id,
				     jsonb_build_object(
			    'object_codes', jsonb_build_array(v_agreement_code),
			    'get_actions', true,
			    'get_templates', true));
end;
$BODY$
  LANGUAGE plpgsql volatile
  COST 100;

insert into data.action_generators(function, params, description) values
(
  'generate_if_string_attribute',
  '{
    "attributes": {
      "type": {
        "draft_agreements": [
          {"function": "create_agreement"}
          ],
        "agreement": [
          {"function": "confirm_agreement"},
          {"function": "reject_agreement"},
          {"function": "cancel_agreement"},
          {"function": "delete_agreement"}
          ]
      }
    }
  }',
  null
);