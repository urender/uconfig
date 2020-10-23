{%
	let phys = wiphy.lookup_by_band(radio.band);

	if (!length(phys)) {
		warn("Can't find any suitable radio phy for band %s radio settings", radio.band);

		return;
	}

	function match_htmode(phy, radio) {
		let channel_mode = radio.channel_mode;
		let channel_width = radio.channel_width;
		let fallback_modes = { HE: /^(HE|VHT|HT)/, VHT: /^(VHT|HT)/, HT: /^HT/ };
		let mode_weight = { HT: 1, VHT: 10, HE: 100 };
		let wanted_mode = channel_mode + (channel_width == 8080 ? "80+80" : channel_width);

		let supported_phy_modes = map(sort(map(phy.htmode, (mode) => {
			let m = match(mode, /^([A-Z]+)(.+)$/);
			return [ mode, mode_weight[m[1]] * (m[2] == "80+80" ? 159 : +m[2]) ];
		}), (a, b) => (b[1] - a[1])), i => i[0]);
		supported_phy_modes = filter(supported_phy_modes, mode =>
			!(index(phy.band, "2G") >= 0 && mode == "VHT80"));
		if (wanted_mode in supported_phy_modes)
			return wanted_mode;

		for (let supported_mode in supported_phy_modes) {
			if (match(supported_mode, fallback_modes[channel_mode])) {
				warn("Selected radio does not support requested HT mode %s, falling back to %s",
					wanted_mode, supported_mode);
				delete radio.channel;
				return supported_mode;
			}
		}

		die("Selected radio does not support any HT modes");
	}

	/* list of valid channels per channel width (values taken from hostapd src) */
	let channel_list = {
		"160": [ 36, 100 ],
		"80": [ 36,  52, 100, 116, 132, 149 ],
		"40": [ 36, 44, 52, 60, 100, 108, 116,
			124, 132, 140, 149, 157, 165, 173,
			184, 192 ]
	};

	/* set all 5G channels as valid if there was no override in the config */
	if (!length(radio.valid_channels) && radio.band == "5G")
		radio.valid_channels = [ 36, 44, 52, 60, 100, 108, 116, 124, 132,
					 140, 149, 157, 165, 173, 184, 192 ];

	/* set all 6G channels as valid if there was no override in the config */
	if (!length(radio.valid_channels) && radio.band == "6G")
		radio.valid_channels = [ 1, 2, 5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49, 53, 57, 61, 65, 69, 73,
					 77, 81, 85, 89, 93, 97, 101, 105, 109, 113, 117, 121, 125, 129, 133, 137, 141,
					 145, 149, 153, 157, 161, 165, 169, 173, 177, 181, 185, 189, 193, 197, 201, 205,
					 209, 213, 217, 221, 225, 229, 233 ];

	/**
	 * helper function to check if a channel is allowed for a specific bandwidth
	 */
	function allowed_channel(radio) {
		/* all channels are allowed on 20MHz */
		if (radio.channel_width == 20)
			return true;

		/* check if channel-width is known */
		if (!channel_list[radio.channel_width])
			return false;

		/* check if the channel is a valid one for the given bandwitdh */
		if (!(radio.channel in channel_list[radio.channel_width]))
			return false;

		/* check if the PHY actually supports this channel */
		if (radio.valid_channels && !(radio.channel in radio.valid_channels))
			return false;

		/* all good */
		return true;
	}

	/**
	 * wor
	 */
	function match_channel(phy, radio) {
		let wanted_channel = radio.channel;

		/* if ACS was requested return 0 */
		if (!wanted_channel || wanted_channel == "auto")
			return 0;

		/* check if the requested channel is valid when the PHY is a 5G one, otherwise default to ACS */
		if (index(phy.band, "5G") >= 0 && !allowed_channel(radio)) {
			warn("Selected radio does not support requested channel %d, falling back to ACS",
				wanted_channel);
			return 0;
		}

		/* verify that the wanted channel is supported by the phy */
		if (wanted_channel in phy.channels)
			return wanted_channel;

		/* work out constraints for guessing a good channel */
		let min = (wanted_channel <= 14) ?  1 :  32;
		let max = (wanted_channel <= 14) ? 14 : 196;
		let eligible_channels = filter(phy.channels, (ch) => (ch >= min && ch <= max));

		/* try to find a channel next to the wanted one */
		for (let i = length(eligible_channels); i > 0; i--) {
			let candidate = eligible_channels[i - 1];

			if (candidate < wanted_channel || i == 1) {
				warn("Selected radio does not support requested channel %d, falling back to %d",
					wanted_channel, candidate);

				return candidate;
			}
		}

		/* if all of the above failed, drop down to first channel that the PHY supports */
		warn("Selected radio does not support any channel in the target frequency range, falling back to %d",
			phy.channels[0]);

		return phy.channels[0];
	}

	/**
	 * helper function to match the best mimo mode
	 */
	function match_mimo(available_ant, wanted_mimo) {
		/* if no mimo is requested, use all available antennas */
		if (!radio.mimo)
			return available_ant;

		/* some PHYs will use the 4 upper bits to select antennas */
		let shift = ((available_ant & 0xf0) == available_ant) ? 4 : 0;

		/* make sure that the requested mimo has the correct syntax */
		let m = match(wanted_mimo, /^([0-9]+)x([0-9]+$)/);
		if (!m) {
			warn("Failed to parse MIMO mode, falling back to %d", available_ant);

			return available_ant;
		}

		/* make sure that the HW supports the requested mimo mode */
		let use_ant = 0;
		for (let i = 0; i < m[1]; i++)
			use_ant += 1 << i;

		if (!use_ant || (use_ant << shift) > available_ant) {
			warn("Invalid or unsupported MIMO mode %s specified, falling back to %d",
				wanted_mimo || 'none', available_ant);

			return available_ant;
		}

		/* all good */
		return use_ant << shift;
	}

	/**
	 * convert the requeste HT mode to what UCI expects
	 */
	function match_require_mode(require_mode) {
		let modes = { HT: "n", VHT: "ac", HE: "ax" };

		return modes[require_mode] || '';
	}
%}

# Radio Configuration
{% for (let phy in phys): %}
{%  let htmode = match_htmode(phy, radio) %}
set wireless.{{ phy.section }}.disabled=0
set wireless.{{ phy.section }}.uconfig_path={{ s(location) }}
set wireless.{{ phy.section }}.htmode={{ htmode }}
set wireless.{{ phy.section }}.channel={{ match_channel(phy, radio) }}
set wireless.{{ phy.section }}.txantenna={{ match_mimo(phy.tx_ant, radio.mimo) }}
set wireless.{{ phy.section }}.rxantenna={{ match_mimo(phy.rx_ant, radio.mimo) }}
set wireless.{{ phy.section }}.beacon_int={{ radio.beacon_interval }}
set wireless.{{ phy.section }}.country={{ s(radio.country) }}
set wireless.{{ phy.section }}.require_mode={{ s(match_require_mode(radio.require_mode)) }}
set wireless.{{ phy.section }}.txpower={{ radio.tx_power }}
set wireless.{{ phy.section }}.legacy_rates={{ b(radio.legacy_rates) }}
set wireless.{{ phy.section }}.chan_bw={{ radio.bandwidth }}
set wireless.{{ phy.section }}.maxassoc={{ radio.maximum_clients }}
set wireless.{{ phy.section }}.acs_exclude_dfs={{ b(!radio.allow_dfs) }}
set wireless.{{ phy.section }}.noscan=1
set wireless.{{ phy.section }}.reconf=1
{% if (radio.allow_dfs) for (let channel in radio.valid_channels): %}
add_list wireless.{{ phy.section }}.channels={{ channel }}
{% endfor %}
{%  if (radio.he_settings && phy.he_mac_capa && match(htmode, /HE.*/)): %}
set wireless.{{ phy.section }}.he_bss_color={{ radio.he_settings.bss_color }}
set wireless.{{ phy.section }}.multiple_bssid={{ b(radio.he_settings.multiple_bssid) }}
set wireless.{{ phy.section }}.ema={{ b(radio.he_settings.ema) }}
{%  endif %}
{%  if (radio.rates): %}
set wireless.{{ phy.section }}.basic_rate={{ radio.rates.beacon }}
set wireless.{{ phy.section }}.mcast_rate={{ radio.rates.multicast }}
{%  endif %}
{%  if (radio.band == "6G"): %}
set wireless.{{ phy.section }}.he_co_locate={{ b(1) }}
{%  endif %}
{% endfor %}
