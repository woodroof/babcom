-- drop function pallas_project.init_claims();

create or replace function pallas_project.init_claims()
returns void
volatile
as
$$
declare

begin
  -- Атрибуты 
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('claim_author', 'Автор иска', 'Автор иска', 'normal', 'full', 'pallas_project.vd_link', false),
  ('claim_plaintiff', 'Истец', 'Истец', 'normal', 'full', 'pallas_project.vd_link', false),
  ('claim_defendant', 'Ответчик', 'Ответчик', 'normal', 'full', 'pallas_project.vd_link', false),
  ('claim_text', null, 'Текст иска', 'normal', 'full', null, false),
  ('claim_result_text', 'Результат рассмотрения иска', 'Результат рассмотрения иска', 'normal', 'full', null, false),
  ('claim_time', 'Дата создания иска', 'Время создания иска', 'normal', null, null, false),
  ('claim_result_time', 'Дата принятия решения', 'Дата принятия решения', 'normal', null, null, false),
  ('claim_status', 'Статус', 'Статус иска', 'normal', null, 'pallas_project.vd_claim_status', false),
  ('system_claim_id', null, 'Идентификатор иска для списка редактирования ответчика', 'system', null, null, false),
  ('system_claim_to_asj', null, 'Признак того, что иск направлен в АСС', 'system', null, null, false);

  -- Объект - страница для работы с исками
  perform data.create_object(
  'claims',
  jsonb '[
    {"code": "title", "value": "Судебные иски"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": ["claims_my", "claims_all"]},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_claims_list"},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "claim_group", "attributes": ["description"], "actions": ["claim_create"]}]
      }
    }
  ]');

  -- Списки исков
  -- Класс
  perform data.create_class(
  'claim_list',
  jsonb '[
    {"code": "is_visible", "value": true},
    {"code": "content", "value": []},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_claims_list"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{"code": "claim_list_group", "attributes": ["description"], "actions": ["claim_create"]}]
      }
    }
  ]');

  perform data.create_object(
  'claims_all',
  jsonb '[
    {"code": "title", "value": "Все иски"},
    {"code": "is_visible", "value": true}
  ]',
  'claim_list');

  perform data.create_object(
  'claims_my',
  jsonb '[
    {"code": "title", "value": "Мои иски"},
    {"code": "is_visible", "value": true}
  ]',
  'claim_list');

  -- Объект-класс для иска
  perform data.create_class(
  'claim',
  jsonb '[
    {"code": "type", "value": "claim"},
    {"code": "priority", "value": 82},
    {"code": "is_visible", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_claim"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "subtitle": "claim_status",
        "groups": []
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [
          {
            "code": "claim_group1",
            "attributes": ["claim_status", "claim_time", "claim_author", "claim_plaintiff", "claim_defendant"]
          },
          {
            "code": "claim_group2",
            "attributes": ["claim_text"],
            "actions": ["claim_change_defendant", "claim_edit", "claim_delete"]
          },
          {
            "code": "claim_group3",
            "attributes": ["claim_result_time", "claim_result_text"],
            "actions": ["claim_send", "claim_send_to_judge", "claim_result", "claim_result_edit", "claim_chat"]
          }
        ]
      }
    }
  ]');

  -- Объект-класс для временных списков персон для редактирования иска
  perform data.create_class(
  'claim_temp_defendant_list',
  jsonb '[
    {"code": "content", "value": []},
    {"code": "actions_function", "value": "pallas_project.actgenerator_claim_temp_defendant_list"},
    {"code": "list_element_function", "value": "pallas_project.lef_claim_temp_defendant_list"},
    {"code": "temporary_object", "value": true},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [
          {
            "code": "group1",
            "actions": ["claim_back"]
          }
        ]
      }
    }
  ]');

  insert into data.actions(code, function) values
  ('claim_create', 'pallas_project.act_claim_create'),
  ('claim_change_defendant', 'pallas_project.act_claim_change_defendant'),
  ('claim_edit','pallas_project.act_claim_edit'),
  ('claim_delete','pallas_project.act_claim_delete'),
  ('claim_send', 'pallas_project.act_claim_send'),
  ('claim_result', 'pallas_project.act_claim_result'),
  ('claim_result_edit', 'pallas_project.act_claim_result_edit'),
  ('claim_chat', 'pallas_project.act_claim_chat'),
  ('claim_send_to_judge', 'pallas_project.act_claim_send_to_judge');
end;
$$
language plpgsql;
