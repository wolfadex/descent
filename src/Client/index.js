import Bugout from "bugout";
import httpHijack from "../http-hijack.js";
import { Elm } from "./Main.elm";
import { trackers } from "../utils.js";

const app = Elm.Client.Main.init({
	node: document.getElementById("root"),
});

httpHijack("bugout", window, function(router) {
	router.post("connect", function(req, res) {
		const serverAddress = req.body;
		const client = new Bugout(serverAddress, {
			announce: trackers,
		});

		client.on("server", function() {
			console.log("connected");
			res.json({ client });
		});

		client.on("message", function(address, message) {
			console.log("Message received", address === serverAddress, message);
			app.ports.messageReceived.send([address, message]);
		});
	});

	router.post("message", function(req, res) {
		const { client, message, timestamp } = req.body;

		client.rpc("message", message, function(actualTimestamp) {
			app.ports.messageReceived.send({ timestamp, actualTimestamp });
		});
	});
});

app.ports.unknownServerMessage.subscribe(function(err) {
	console.log("The server sent a message the client doesn't recognize", err);
});
