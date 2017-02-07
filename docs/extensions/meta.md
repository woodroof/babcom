# Работа с метасущностями
Метасущности — объекты и действия, к которым есть быстрый доступ у объекта, которым управляет пользователь. Например, могут отображаться в боковом меню приложения.

## Наличие поддержки
Если в возвращаемом значении функции *get\_extensions* есть строка **"meta"**, то сервер поддерживает работу с метасущностями.

## Получение списка метасущностей
Метасущности хранятся в атрибуте *meta\_entities* объекта, которым управляет пользователь. По умолчанию при запросе объекта пользователя атрибут клиенту не отдаётся.
Формат описания метасущностей:

	{
		"groups": [
			{
				"name": "<имя группы для отображения>",
				"objects": [
					{
						"code": "<код объекта>",
						"name": "<имя для отображения>"
					},
					...
				],
				"actions": [
					{
					},
					...
				]
			},
			...
		]
	}
Каждая группа имеет заголовок, затем отображаются объекты в порядке их следования в поле *objects*, затем идут действия группы в порядке их следования в поле *actions*. Поля *objects* и *actions* могут отсутствовать. Если поле *name* группы отсутствует, группа не имеет заголовка.  
Содержимое объекта в массиве *actions* полностью совпадает по формату с объектами, содержащимися в соответствующем поле ответа функции *get\_objects*.

## Определение наличия изменений
Рекомендуется после любого выполнения действия или получения объекта или списка объектов дополнительно отправлять запрос на проверку наличия изменений.