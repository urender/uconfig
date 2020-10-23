#!/usr/bin/ucode

'use strict';

import * as fs from 'fs';
import * as wiphy from 'uconfig.wiphy';

/* create base dicitionary, tracking the time of creation */
let capa = {
	uuid: time(),
};

/* open the board file */
let boardfile = fs.open("/etc/board.json", "r");
let board = json(boardfile.read("all"));
boardfile.close();

/* grab compat string and long name */
capa.compatible = replace(board.model.id, ',', '_');
capa.model = board.model.name;

/* figure out if this as an AP or a switch */
if (board.bridge && board.bridge.name == "switch")
	capa.platform = "switch";
else if (length(wiphy.phys))
	capa.platform = "ap";
else
	capa.platform = "router";

/* gather networking capabilities */
capa.network = {};

/* check if the board.json contains MAC overrides */
let macs = {};
for (let k, v in board.network) {
	if (!board.network.wan && k == 'lan')
		k = 'wan';
	if (v.ports)
		capa.network[k] = v.ports;
	if (v.device)
		capa.network[k] = [v.device];
	if (v.ifname)
		capa.network[k] = split(replace(v.ifname, /^ */, ''), " ");
	if (v.macaddr)
		macs[k] = v.macaddr;
}

if (length(macs))
	capa.macaddr = macs;

/* store the label_macaddr */
if (board.system?.label_macaddr)
	capa.label_macaddr = board.system?.label_macaddr;

/* if this is a switch we want to track that info */
if (board.switch)
	capa.switch = board.switch;

/* gather basic info abotu the wireless PHYs */
if (length(wiphy.phys)) {
	capa.wifi = [ ];
	for (let k, v in wiphy.phys) {
		/* channel info depends on current reg domain, so do not track it */
		delete v.channels;
		delete v.frequencies;
		delete v.dfs_channels;
		push(capa.wifi, { phy: k, ...v });
	}
}

let capafile = fs.open("/etc/uconfig/capabilities.json", "w");
capafile.write(capa);
capafile.close();
