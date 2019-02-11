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
  ('document_last_edit_time', null, 'Дата и время последнего редактирования документа', 'normal', 'full', null, true),
  ('system_document_participants', null, 'Участники, подписывающие документ', 'system', null, null, false),
  ('document_participants', null, 'Участники, подписывающие документ', 'normal', 'full', null, false),
  ('document_sent_to_sign', null, 'Признак того, что документ был отправлен на подпись', 'normal', 'full', null, false);

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
    {"code": "content", "value": ["rules_documents", "my_documents", "official_documents"]},
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
        "groups": [{"code": "document_group", "attributes": ["document_author", "document_last_edit_time", "document_text", "document_participants", "document_sent_to_sign"]}]
      }
    }
  ]');


  insert into data.actions(code, function) values
  ('document_create', 'pallas_project.act_document_create');

end;
$$
language plpgsql;
