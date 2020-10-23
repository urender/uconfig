/**
 * @class uconfig.services
 * @classdesc
 *
 * The services utility class provides methods for managing and querying
 * service states.
 */

/** @lends uconfig.services.prototype */

'use strict';

import * as fs from 'fs';

export let services = {};

export function set_enabled(name, enable) {
	if (type(enable) == 'bool')
		services[name] = enable ? 'start' : 'stop';
	else
		services[name] = enable;
};

export function is_present(name) {
	return length(fs.stat("/etc/init.d/" + name)) > 0;
};

export function lookup_interfaces(service) {
	let interfaces = [];

	for (let name, interface in state.interfaces) {
		if (!interface.services || index(interface.services, service) < 0)
			continue;
		push(interfaces, interface);
	}

	return interfaces;
};

export function lookup_ssids(service) {
	let ssids = [];

	for (let name, interface in state.interfaces) {
		if (!interface.ssids)
			continue;
		for (let ssid in interface.ssids) {
			if (!ssid.services || index(ssid.services, service) < 0)
				continue;
			push(ssids, ssid);
		}
	}

	return ssids;
};

export function lookup_ethernet(service) {
	let ethernets = [];

	for (let ethernet in state.ethernet) {
		if (!ethernet.services || index(ethernet.services, service) < 0)
			continue;
		push(ethernets, ethernet);
	}

	return ethernets;
};

export function lookup_services() {
	let rv = [];

	for (let incfile in fs.glob(topdir + '/templates/services/*.uc')) {
		let m = match(incfile, /^.+\/([^\/]+)\.uc$/);

		if (m)
			push(rv, m[1]);
	}

	return rv;
};

export function lookup_metrics() {
	let rv = [];

	for (let incfile in fs.glob(topdir + '/templates/metric/*.uc')) {
		let m = match(incfile, /^.+\/([^\/]+)\.uc$/);

		if (m)
			push(rv, m[1]);
	}

	return rv;
};

function set_state(state) {
        for (let service, enable in services) {
                if (enable != state)
                        continue;
                printf('%s %s\n', service, enable);
                system(`/etc/init.d/${service} ${enable}`);
        }
};

export function start() {
	set_state('start');
	set_state('restart');
};

export function stop() {
	set_state('stop');
};

export function init() {
	services = {};
};
