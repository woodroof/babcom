-- drop function pallas_project.init_blogs();

create or replace function pallas_project.init_blogs()
returns void
volatile
as
$$
declare

begin
  -- Атрибуты 
  insert into data.attributes(code, name, description, type, card_type, value_description_function, can_be_overridden) values
  -- для блогов
  ('system_blog_author', null, 'Автор блога', 'system', null, null, false),
  ('blog_author', 'Автор', 'Автор блога', 'normal', 'full', 'pallas_project.vd_link', true),
  ('blog_is_mute', null, 'Признак отлюченного уведомления о новых сообщениях блога', 'normal', null, 'pallas_project.vd_chat_is_mute', true),
  ('blog_message_text', null, 'Текст сообщения в блоге', 'normal', 'full', null, false),
  ('blog_message_time', null, 'Время публикации', 'normal', null, null, false),
  ('system_blog_message_like', null, 'Признак того, что вы залайкали сообщение', 'system', null, null, true),
  ('blog_message_like_count', null, 'Количество лайков у сообщения', 'system', null, null, false),
  ('blog_name', null, 'Название блога', 'normal', null, 'pallas_project.vd_link', false),
  ('blog_is_confirmed', null, 'Признак, что блог подтверждён', 'normal', null, 'pallas_project.vd_blog_is_confirmed', false);

  -- Списки блогов
  perform data.create_object(
  'blogs_all',
  jsonb '[
    {"code": "title", "value": "Все блоги"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": []},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
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
        "groups": []
      }
    }
  ]');

  perform data.create_object(
  'blogs_my',
  jsonb '[
    {"code": "title", "value": "Мои блоги"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": []},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_blogs_my"},
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
        "groups": [{
          "code": "blog_my_group1",
          "actions": ["blog_create"]
        }]
      }
    }
  ]');

  -- Объект для ленты новостей
  perform data.create_object(
  'news',
  jsonb '[
    {"code": "title", "value": "Новости"},
    {"code": "is_visible", "value": true},
    {"code": "content", "value": []},
    {"code": "description", "value": "Хотите опубликовать свою новость? Это просто! Нажимайте \"Мои блоги\", создавайте блог, пишите в него, и все увидят вашу версию событий."},
    {"code": "actions_function", "value": "pallas_project.actgenerator_blogs_news"},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "list_actions_function", "value": "pallas_project.actgenerator_blog_content"},
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{
            "code": "blog_group1",
            "attributes": ["description"],
            "actions": ["blogs_my", "blogs_all"]
          }]
      }
    }
  ]');

  -- Объект-класс для блога
  perform data.create_class(
  'blog',
  jsonb '[
    {"code": "type", "value": "blog"},
    {"code": "priority", "value": 84},
    {"code": "content", "value": []},
    {"code": "is_visible", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_blog"},
    {"code": "independent_from_actor_list_elements", "value": true},
    {"code": "independent_from_object_list_elements", "value": true},
    {"code": "list_actions_function", "value": "pallas_project.actgenerator_blog_content"},
    {
      "code": "mini_card_template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [{
          "code": "blog_group1",
          "actions": ["blog_mute"]
        }]
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [
          {
            "code": "blog_group1",
            "attributes": ["blog_is_confirmed", "blog_author", "blog_is_mute"],
            "actions": ["blog_write", "blog_mute", "blog_rename"]
          }
        ]
      }
    }
  ]');

    -- Объект-класс для сообщения
  perform data.create_class(
  'blog_message',
  jsonb '[
    {"code": "type", "value": "blog_message"},
    {"code": "is_visible", "value": true},
    {"code": "actions_function", "value": "pallas_project.actgenerator_blog_message"},
    {
      "code": "mini_card_template",
      "value": {
        "groups": [
          {"code": "blog_message_group1", 
            "attributes": ["blog_name", "blog_message_time", "title"], 
            "actions": ["blog_message_like", "blog_message_edit", "blog_message_delete", "blog_message_chat"]
          }
        ]
      }
    },
    {
      "code": "template",
      "value": {
        "title": "title",
        "subtitle": "subtitle",
        "groups": [
           {"code": "blog_message_group1",
            "attributes": ["blog_name", "blog_message_time", "blog_message_text"], 
            "actions": ["blog_message_like", "blog_message_edit", "blog_message_delete", "blog_message_chat"]
           }
        ]
      }
    }
  ]');

  insert into data.actions(code, function) values
  ('blog_create', 'pallas_project.act_blog_create'),
  ('blog_write', 'pallas_project.act_blog_write'),
  ('blog_mute','pallas_project.act_blog_mute'),
  ('blog_rename','pallas_project.act_blog_rename'),
  ('blog_message_like', 'pallas_project.act_blog_message_like'),
  ('blog_message_edit', 'pallas_project.act_blog_message_edit'),
  ('blog_message_delete', 'pallas_project.act_blog_message_delete'),
  ('blog_message_chat', 'pallas_project.act_blog_message_chat');
end;
$$
language plpgsql;
