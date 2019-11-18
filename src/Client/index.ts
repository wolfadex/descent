// @ts-ignore
import { Elm } from "./Main.elm";
import Bugout from "bugout";

const app = Elm.Client.Main.init({
	node: document.getElementById("root"),
});
let client;

app.ports.connectToServer.subscribe(function(serverAddress) {
	client = new Bugout(serverAddress);

	client.on("server", function() {
		app.ports.serverConnected.send(serverAddress);
	});

	client.on("message", function(address, message) {
		console.log("Message received", address === serverAddress, message);
		app.ports.messageReceived.send([address, message]);
	});
});

app.ports.sendMessage.subscribe(function(content) {
	client.rpc("message", content, () => {});
});

app.ports.unknownServerMessage.subscribe(function(err) {
	console.log("The server sent a message the client doesn't recognize", err);
});
