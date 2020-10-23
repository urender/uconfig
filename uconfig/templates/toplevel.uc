{%
	/* reject the config if there is no valid UUID */
	if (!state.uuid) {
		state.strict = true;
		error('Configuration must contain a valid UUID. Rejecting whole file');
		return;
	}

	/* reject the config if there is no valid upstream configuration */
	let upstream;
	for (let i, interface in state.interfaces) {
		if (interface.role != 'upstream')
			continue;
		upstream = interface;
	}

	if (!upstream) {
		state.strict = true;
		error('Configuration must contain at least one valid upstream interface. Rejecting whole file');
		return;
	}

	// reject config if a wired port is used twice in un-tagged mode
	let untagged_ports = [];
	for (let i, interface in state.interfaces) {
		if (interface.role != 'upstream')
			continue;
		let eth_ports = ethernet.lookup_by_interface_vlan(interface);
		for (let port in keys(eth_ports)) {
			if (ethernet.port_vlan(interface, eth_ports[port]))
				continue;
			if (port in untagged_ports) {
				state.strict = true;
				error('duplicate usage of un-tagged ports: ' + port);
				return;
			}
			push(untagged_ports, port);
		}
	}

	/* assign an index to each interface */
	let idx = 0;
	for (let name, interface in state.interfaces)
		interface.index = idx++;

	/* find out which vlans are used and which should be assigned dynamically */
	let vlans = [];
	let vlans_upstream = [];
	for (let name, interface in state.interfaces) {
		interface.name = name;
		if (ethernet.has_vlan(interface)) {
			push(vlans, interface.vlan.id);
			if (interface.role == 'upstream')
				push(vlans_upstream, interface.vlan.id);
		} else
			interface.vlan = { id: 0 };
	}

	/* dynamically assigned vlans start at 4090 counting backwards */
	let vid = 4090;
	function next_free_vid() {
		while (vid in vlans)
			vid--;
		return vid--;
	}

	/* dynamically assign vlan ids to all interfaces that have none yet */
	for (let i, interface in state.interfaces)
		if (!interface.vlan.id)
			interface.vlan.dyn_id = next_free_vid();

	/* force auto channel if there are any sta interfaces on the radio */
	for (let i, radio in state.radios) {
		if (!radio.channel || radio.channel == 'auto')
			continue;
		for (let j, iface in state.interfaces)
			for (let s, ssid in iface.ssids)
		if (ssid.bss_mode in [ 'sta', 'wds-sta', 'wds-repeater' ]) {
			warn('Forcing Auto-Channel as a STA interface is present');
			delete radio.channel;
		}
	}

	/* render the basic UCI setup */
	include('base.uc');

	/* render the unit configuration */
	if (!state.unit)
		state.unit = {
			leds_active: true,
			tty_login: false,
			password: false,
		};
	include('unit.uc', { location: '/unit', unit: state.unit });

	state.services ??= {};
	for (let service in services.lookup_services())
		tryinclude('services/' + service + '.uc', {
			location: '/services/' + service,
			[service]: state.services[service] || {}
		});

	state.metrics ??= {};
	for (let metric in services.lookup_metrics())
		tryinclude('metric/' + metric + '.uc', {
			location: '/metric/' + metric,
			[metric]: state.metrics[metric] || {}
		});

	/* render the ethernet port configuration */
	tryinclude('ethernet.uc', { location: '/ethernet/' });

	/* render the wireless PHY configuration */
	for (let i, radio in state.radios)
		tryinclude('radio.uc', { location: '/radios/' + i, radio });

	/* render the logical interface configuration (includes SSIDs) */
	function iterate_interfaces(role) {
		for (let i, interface in state.interfaces) {
			if (interface.role != role)
				continue;
			include('interface.uc', { location: '/interfaces/' + i, interface, vlans_upstream });
		}
	}

	iterate_interfaces("upstream");
	iterate_interfaces("downstream");
%}
