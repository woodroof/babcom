insert into data.attributes(type, code, name, description) values
('SYSTEM', 'system_priority', 'Приоритет объекта', 'Используется для определения используемого значения атрибута в случае, когда есть несколько значений для разных объектов, в которые входит объект, от имени которого происходит действие. Приоритет для значения без объекта считается равным нулю.'),
('SYSTEM', 'system_is_visible', 'Видимость объекта', 'Если значение равно "true", то объект виден.');

insert into data.logins(description) values
('Бесправный пользователь для работы без авторизации');

insert into data.params(code, value, description)
select 'default_login', to_jsonb(l.id), 'Идентификатор бесправного login''а для входа без авторизации'
from data.logins l;