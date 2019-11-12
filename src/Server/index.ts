// @ts-ignore
import { Elm } from "./Main.elm";
import Bugout from "bugout";

type Name = string;

const SERVER_NAME_PREFIX = "wolfadex__chat__server__";
// @ts-ignore
const servers = Object.entries(localStorage).reduce(function(
	foundServers,
	[key, value],
) {
	if (key.startsWith(SERVER_NAME_PREFIX)) {
		return {
			...foundServers,
			[key]: value,
		};
	} else {
		return foundServers;
	}
},
{});
const app = Elm.Server.Main.init({
	node: document.getElementById("root"),
	flags: existingServerNames(),
});
let currentServer;

app.ports.startServer.subscribe(function(name): void {
	if (servers[`${SERVER_NAME_PREFIX}${name}`] == null) {
		currentServer = new Bugout();
	} else {
		currentServer = new Bugout({
			seed: servers[`${SERVER_NAME_PREFIX}${name}`],
		});
	}

	servers[`${SERVER_NAME_PREFIX}${name}`] = currentServer.seed;
	localStorage.setItem(`${SERVER_NAME_PREFIX}${name}`, currentServer.seed);
	registerAPI();
	app.ports.serverStarted.send([name, currentServer.address()]);
});

app.ports.shutDownServer.subscribe(function(): void {
	if (currentServer != null) {
		currentServer.destroy(function() {
			app.ports.serverShutDown.send(existingServerNames());
		});
	} else {
		app.ports.serverShutDown.send(existingServerNames());
	}
});

app.ports.deleteServer.subscribe(function(name): void {
	localStorage.removeItem(`${SERVER_NAME_PREFIX}${name}`);
	delete servers[`${SERVER_NAME_PREFIX}${name}`];
});

function registerAPI(): void {
	currentServer.register("ping", function(clientAddress, args, respond) {
		console.log(args);
		respond({ message: "pong" });
	});
}

function existingServerNames(): Array<Name> {
	return Object.keys(servers).map((name) =>
		name.replace(SERVER_NAME_PREFIX, ""),
	);
}
