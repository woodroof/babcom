var socket;
var uuid = uuidv4();

var requests = {
	'get_actors': '{}',
	'get_more': '{\n\t\t"object_id": "ID"\n\t}',
	'make_action': '{\n\t\t"action_code": "CODE",\n\t\t"params": null,\n\t\t"user_params": {\n\t\t}\n\t}',
	'open_list_object': '{\n\t\t"object_id": "ID",\n\t\t"list_object_id": "ID"\n\t}',
	'set_actor': '{\n\t\t"actor_id": "ID"\n\t}',
	'subscribe': '{\n\t\t"object_id": "ID"\n\t}',
	'touch': '{\n\t\t"object_id": "ID"\n\t}',
	'unsubscribe': '{\n\t\t"object_id": "ID"\n\t}'
};

function uuidv4()
{
	return ([1e7]+-1e3+-4e3+-8e3+-1e11).replace(/[018]/g, c =>
	  (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)
	)
}

function newMessage(msg)
{
	var message = document.createElement('div');
	message.className = 'message';
	message.innerHTML = msg;

	var messages = document.getElementById('messages');
	messages.insertBefore(message, messages.firstChild);
}

function setFullMessage(message_text)
{
	var text_field = document.getElementById('send_text');
	text_field.value = message_text;
}

function createOldMessageCallback(message_text)
{
	return () => setFullMessage(message_text);
}

function addClientMessage(message_title, message_body)
{
	var message = document.createElement('div');
	message.className = 'client_message';
	message.innerText = '⇒ ' + message_title;
	message.onclick = createOldMessageCallback(message_body);

	var message_line = document.createElement('div');
	message_line.appendChild(message);

	var messages = document.getElementById('messages');
	messages.insertBefore(message_line, messages.firstChild);
}

function sendMessage()
{
	var message_text = document.getElementById('send_text').value;

	try
	{
		var parsed_message = JSON.parse(message_text);

		addClientMessage(parsed_message['type'], message_text);

		socket.send(message_text);
	}
	catch (err)
	{
		addClientMessage('<invalid json>', message_text);
	}
	return false;
}

function recreateSocket()
{
	var send_button = document.getElementById('send_button')
	send_button.className = 'disabled_button';
	send_button.onclick = '';

	setTimeout(createSocket, 1000);
}

function createSocket()
{
	socket = new WebSocket("wss://harmlessapps.com/api/" + uuid);
	socket.onopen =
		function()
		{
			var send_button = document.getElementById('send_button');
			send_button.className = 'button';
			send_button.onclick = sendMessage;
		};
	socket.onclose = function(event) { recreateSocket(); };
	socket.onmessage = function(event) { newMessage(event.data); };
}

function setMessage(type, data)
{
	var text_field = document.getElementById('send_text');
	text_field.value = '{\n\t"request_id": "1",\n\t"type": "' + type + '",\n\t"data": ' + data + '\n}';
}

function createRequestCallback(key)
{
	return () => setMessage(key, requests[key]);
}

function generateRequests()
{
	var parent = document.getElementById('actions');
	for (var key in requests)
	{
		var request = document.createElement('div');
		request.className = 'request';
		request.onclick = createRequestCallback(key);
		request.innerText = key;
		parent.appendChild(request);
	}
}

function init()
{
	generateRequests();
	createSocket();
}

function clearMessages()
{
	var messages = document.getElementById('messages');
	while (messages.firstChild) {
		messages.removeChild(messages.firstChild);
	}
}