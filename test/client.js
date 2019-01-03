var socket;
var uuid = uuidv4();

var requests = {
	'get_actors': '{}',
	'get_more': '{\n\t\t"object_id": "ID"\n\t}',
	'make_action': '{\n\t\t"action_code": "CODE",\n\t\t"params": null,\n\t\t"user_params": {\n\t\t}\n\t}',
	'set_actor': '{\n\t\t"actor_id": "ID"\n\t}',
	'subscribe': '{\n\t\t"object_id": "ID"\n\t}',
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

function sendMessage()
{
	var text_field = document.getElementById('send_text');
	socket.send(text_field.value);
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
	socket = new WebSocket("ws://localhost:8000/api/" + uuid);
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

function createCallback(key)
{
	return () => setMessage(key, requests[key]);
}

function generateRequests()
{
	var parent = document.getElementById('requests');
	for (var key in requests)
	{
		var request = document.createElement('div');
		request.className = 'request';
		request.onclick = createCallback(key);
		request.innerText = key;
		parent.appendChild(request);
	}
}

function init()
{
	generateRequests();
	createSocket();
}