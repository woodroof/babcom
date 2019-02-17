-- drop function pallas_project.init_documents();

create or replace function pallas_project.init_documents()
returns void
volatile
as
$$
declare

begin
  -- Атрибуты для документов
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  ('system_document_category', null, 'Категория документа', 'system', null, null, false),
  ('document_text', null, 'Текст документа', 'normal', 'full', null, false),
  ('system_document_author', null, 'Автор документа', 'system', null, null, false),
  ('document_author', null, 'Автор документа', 'normal', 'full', null, true),
  ('document_last_edit_time', 'Последнее обновление', 'Дата и время последнего редактирования документа', 'normal', 'full', null, true),
  ('system_document_participants', null, 'Участники, подписывающие документ', 'system', null, null, false),
  ('document_participants', 'Подписи', 'Участники, подписывающие документ', 'normal', 'full', null, false),
  ('document_status', 'Статус', 'Статус документа', 'normal', 'full', 'pallas_project.vd_document_status', false),
  -- для дополнительных
  ('system_document_temp_share_list', null, 'Список кодов тех, с кем поделиться', 'system', null, null, false),
  ('document_temp_share_list', 'Поделиться с', 'Список персонажей, с которыми хотим поделиться документом', 'normal', 'full', null, false),
  ('system_document_temp_list_document_id', null, 'Идентификатор документа', 'system', null, null, false),
  ('document_signers_list_participants', 'Участники', 'Участники, подписывающие документ', 'normal', 'full', null, false);

  -- Объекты для категорий документов
  perform data.create_object(
  'rules_documents',
  jsonb '[
    {"code": "title", "value": "Правила"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": []},
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
        "groups": []
      }
    }
  ]');

  perform data.create_object(
  'my_documents',
  jsonb '[
    {"code": "title", "value": "Мои документы"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": []},
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
        "groups": []
      }
    }
  ]');

  perform data.create_object(
  'official_documents',
  jsonb '[
    {"code": "title", "value": "Официальные документы"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": []},
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
        "groups": []
      }
    }
  ]');

  perform data.create_object(
  'documents',
  jsonb '[
    {"code": "title", "value": "Документы"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": ["my_documents", "official_documents", "rules_documents"]},
    {"code": "actions_function", "value": "pallas_project.actgenerator_documents"},
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
        "groups": [{"code": "documents_group", "actions": ["document_create"]}]
      }
    }
  ]');

  perform data.create_class(
  'document',
  jsonb '[
    {"code": "type", "value": "document"},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "is_visible", "value": true},
    {"code": "priority", "value": 95},
    {"code": "actions_function", "value": "pallas_project.actgenerator_document"},
    {"code": "system_document_participants", "value": {}},
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
        "groups": [{"code": "document_group1", "actions": ["document_edit", "document_delete", "document_share_list", "document_add_to_my", "document_make_official"]},
                   {"code": "document_group2", "attributes": ["document_text"]},
                   {"code": "document_group3", "attributes": ["document_status", "document_participants", "document_sent_to_sign"], "actions": ["document_add_signers", "document_send_to_sign", "document_sign"]},
                   {"code": "document_group4", "attributes": ["document_author", "document_last_edit_time"]}]
      }
    }
  ]');

  perform data.create_class(
  'document_temp_share_list',
  jsonb '[
    {"code": "type", "value": "document_temp_share_list"},
    {"code": "temporary_object", "value": true},
    {"code": "list_element_function", "value": "pallas_project.lef_document_temp_share_list"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_document_temp_share_list"},
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
        "groups": [{"code": "document_temp_share_list_group1", "attributes": ["document_temp_share_list"]},
                   {"code": "document_temp_share_list_group2", "actions": ["document_share", "go_back"]}]
      }
    }
  ]');

  perform data.create_class(
  'document_signers_list',
  jsonb '[
    {"code": "type", "value": "document_signers_list"},
    {"code": "temporary_object", "value": true},
    {"code": "is_visible", "value": true, "value_object_code": "master"},
    {"code": "list_element_function", "value": "pallas_project.lef_document_signers_list"},
    {"code": "actions_function", "value": "pallas_project.actgenerator_document_signers_list"},
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
        "groups": [{"code": "document_temp_share_list_group1", "actions": ["go_back"]},
                   {"code": "document_temp_share_list_group2", "attributes": ["document_signers_list_participants"]}
                  ]
      }
    }
  ]');

  insert into data.actions(code, function) values
  ('document_create', 'pallas_project.act_document_create'),
  ('document_edit', 'pallas_project.act_document_edit'),
  ('document_delete', 'pallas_project.act_document_delete'),
  ('document_share', 'pallas_project.act_document_share'),
  ('document_share_list', 'pallas_project.act_document_share_list'),
  ('document_add_to_my', 'pallas_project.act_document_add_to_my'),
  ('document_make_official', 'pallas_project.act_document_make_official'),
  ('document_add_signers', 'pallas_project.act_document_add_signers'),
  ('document_send_to_sign', 'pallas_project.act_document_send_to_sign'),
  ('document_sign', 'pallas_project.act_document_sign');


end;
$$
language plpgsql;
