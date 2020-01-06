import Bugout from "bugout";
import { Elm } from "./Main.elm";
import { trackers } from "../utils.js";

const SERVER_NAME_PREFIX = "wolfadex__chat__server__";
const servers = Object.entries(localStorage).reduce(function(
	foundServers,
	[key, value],
) {
	if (key.startsWith(SERVER_NAME_PREFIX)) {
		return {
			...foundServers,
			[key]: JSON.parse(value),
		};
	} else {
		return foundServers;
	}
},
{});
const app = Elm.Server.Main.init({
	node: document.getElementById("root"),
	flags: existingServers(),
});
let currentServer;

app.ports.startServer.subscribe(function(name) {
	if (servers[`${SERVER_NAME_PREFIX}${name}`] == null) {
		currentServer = new Bugout({
			announce: trackers,
		});
	} else {
		currentServer = new Bugout({
			seed: servers[`${SERVER_NAME_PREFIX}${name}`].seed,
			announce: trackers,
		});
	}

	const serverData = { seed: currentServer.seed };
	servers[`${SERVER_NAME_PREFIX}${name}`] = serverData;
	localStorage.setItem(
		`${SERVER_NAME_PREFIX}${name}`,
		JSON.stringify(serverData),
	);

	registerAPI();
	app.ports.serverStarted.send({
		name,
		address: currentServer.address(),
	});
});

app.ports.shutDownServer.subscribe(function() {
	if (currentServer != null) {
		currentServer.destroy(function() {
			app.ports.serverShutDown.send(existingServers());
		});
	} else {
		app.ports.serverShutDown.send(existingServers());
	}
});

app.ports.deleteServer.subscribe(function(name) {
	localStorage.removeItem(`${SERVER_NAME_PREFIX}${name}`);
	delete servers[`${SERVER_NAME_PREFIX}${name}`];
});

app.ports.forwardMessage.subscribe(function({
	sender,
	recipients,
	content,
	time,
}) {
	if (currentServer != null) {
		console.log("Forwarding message", sender, recipients, content, time);
		recipients.forEach(function(client) {
			currentServer.send(client, {
				action: "forwardMessage",
				payload: { sender, content, time },
			});
		});
	}
});

function registerAPI() {
	currentServer.on("seen", function(clientAddress) {
		app.ports.newClient.send(clientAddress);
	});
	currentServer.register("setUsername", function(
		clientAddress,
		name,
		callback,
	) {
		callback("");
		console.log("TODO", "set user name", clientAddress, name);
		// app.ports.setUsername.send([clientAddress, name]);
	});
	currentServer.register("message", function(clientAddress, content, callback) {
		const actualTimestamp = Math.floor(Date.now() / 1000);
		console.log("Message", clientAddress, content);
		app.ports.messageReceived.send([clientAddress, content, actualTimestamp]);
		callback(actualTimestamp);
	});
}

function existingServers() {
	return Object.keys(servers).map((name) =>
		name.replace(SERVER_NAME_PREFIX, ""),
	);
}
