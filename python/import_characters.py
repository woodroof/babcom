import requests

PROJECT_ID = 100500

TOKEN_URL = 'https://joinrpg.ru/x-api/Token'
CHARACTERS_URL = 'https://joinrpg.ru/x-game-api/{}/characters'.format(PROJECT_ID)
CHARACTER_INFO_BASE_URL = 'https://joinrpg.ru/x-game-api/{}/characters/'.format(PROJECT_ID)

USER = 'user@some.domain'
PASSWORD = 'password'

login_request = requests.post(TOKEN_URL, data={'grant_type': 'password', 'username': USER, 'password': PASSWORD})
access_token = login_request.json()['access_token']

headers = {'Authorization': 'Bearer ' + access_token}
characters_request = requests.get(CHARACTERS_URL, headers=headers)

characters = characters_request.json()

character_infos = []

for character in characters:
	character_id = character['CharacterId']
	character_info_request = requests.get(CHARACTER_INFO_BASE_URL + str(character_id), headers=headers)
	character_infos.append(character_info_request.text)

print('[' + ','.join(character_infos) + ']')