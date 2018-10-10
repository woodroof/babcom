var socket;
var uuid = uuidv4();

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
	socket.send(text_field.innerText);
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