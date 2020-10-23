'use strict';

import * as fs from 'fs';
import * as uci from 'uci';
import * as nl from 'nl80211';

let cursor = uci ? uci.cursor() : null;
let paths = {};
export let phys = {};

let band_freqs = {
	'2G':		[  2412,  2484 ],
	'5G':		[  5160,  5885 ],
	'5G-lower':	[  5160,  5340 ],
	'5G-upper':	[  5480,  5885 ],
	'6G':		[  5925,  7125 ],
	'60G':		[ 58320, 69120 ]
};

let band_channels = {
	'2G':		[ 1, 14 ],
	'5G':		[ 7, 196 ],
	'5G-lower':	[ 7, 68 ],
	'5G-upper':	[ 96, 177 ],
	'6G':		[ 200, 600 ], // FIXME
	'60G':		[ 1, 6 ]
};

function phy_get(wdev) {
        let res = nl.request(nl.const.NL80211_CMD_GET_WIPHY, nl.const.NLM_F_DUMP, { split_wiphy_dump: true });

        if (res === false)
                warn("Unable to lookup phys: " + nl.error() + "\n");

        return res;
}

function add_path(path, phy, index) {
	if (!phy)
		return;

	phy = fs.basename(phy);
	paths[phy] = path;
	if (index)
		paths[phy] += '+' + index;
}

function lookup_paths() {
	let wireless = cursor.get_all('wireless');

	for (let k, section in wireless) {
		if (section['.type'] != 'wifi-device' || !section.path)
			continue;
		let phys = fs.glob(sprintf('/sys/devices/%s/ieee80211/wl*', section.path));
		if (!length(phys))
			phys = fs.glob(sprintf('/sys/devices/platform/%s/ieee80211/wl*', section.path));
		if (!length(phys))
			phys = fs.glob(sprintf('/sys/devices/%s/ieee80211/phy*', section.path));
		if (!length(phys))
			phys = fs.glob(sprintf('/sys/devices/platform/%s/ieee80211/phy*', section.path));

		phys = sort(phys);
		let index = 0;
		for (let phy in phys)
			add_path(section.path, phy, index++);
	}
}

function freq2channel(freq) {
	if (freq == 2484)
		return 14;
	else if (freq < 2484)
		return (freq - 2407) / 5;
	else if (freq >= 4910 && freq <= 4980)
		return (freq - 4000) / 5;
	else if(freq >= 56160 + 2160 * 1 && freq <= 56160 + 2160 * 6)
		return (freq - 56160) / 2160;
	else if (freq >= 5955 && freq <= 7115)
		return (freq - 5950) / 5;
	else
		return (freq - 5000) / 5;
}

function lookup_phys() {
	lookup_paths();

	let phys = phy_get();
	let ret = {};
	for (let phy in phys) {
		let path = paths['wl' + phy.wiphy];
		if (!path)
			path = paths['phy' + phy.wiphy];

		if (!path)
			continue;

		let p = {};

		p.tx_ant = phy.wiphy_antenna_tx || 3;
		p.rx_ant = phy.wiphy_antenna_rx || 3;
		p.frequencies = [];
		p.channels = [];
		p.dfs_channels = [];
		p.htmode = [];
		p.band = [];
		for (let band in phy.wiphy_bands) {
			for (let freq in band?.freqs)
				if (!freq.disabled) {
					push(p.frequencies, freq.freq);
					push(p.channels, freq2channel(freq.freq));
					if (freq.radar)
						push(p.dfs_channels, freq2channel(freq.freq));
					if (freq.freq >= 5995)
						push(p.band, '6G');
					else if (freq.freq <= 2484)
						push(p.band, '2G');
					else if (freq.freq >= 5160 && freq.freq <= 5885)
						push(p.band, '5G');
				}
			if (band?.ht_capa) {
				p.ht_capa = band.ht_capa;
				push(p.htmode, 'HT20');
				if (band.ht_capa & 0x2)
					push(p.htmode, 'HT40');
			}
			if (band?.vht_capa) {
				p.vht_capa = band.vht_capa;
				push(p.htmode, 'VHT20', 'VHT40', 'VHT80');
				let chwidth = (band?.vht_capa >> 2) & 0x3;
				switch(chwidth) {
				case 2:
					push(p.htmode, 'VHT80+80');
					/* fall through */
				case 1:
					push(p.htmode, 'VHT160');
				}
			}
			for (let iftype in band?.iftype_data) {
				if (iftype.iftypes?.ap) {
					p.he_phy_capa = iftype?.he_cap_phy;
					p.he_mac_capa = iftype?.he_cap_mac;
					push(p.htmode, 'HE20');
					let chwidth = (iftype?.he_cap_phy[0] || 0) & 0xff;
					if (chwidth & 0x2 || chwidth & 0x4)
						push(p.htmode, 'HE40');
					if (chwidth & 0x4)
						push(p.htmode, 'HE80');
					if (chwidth & 0x8 || chwidth & 0x10)
						push(p.htmode, 'HE160');
					if (chwidth & 0x10)
						push(p.htmode, 'HE80+80');
				}
			}
		}

		p.band = uniq(p.band);
		if (!length(p.dfs_channels))
			delete p.dfs_channels;
		ret[path] = p;
	}
	return ret;
}

/**
 * Convert a wireless channel to a wireless frequency
 *
 * @param {string} wireless band
 * @param {number} channel
 *
 * @returns {?number}
 * Returns the coverted wireless frequency for this specific
 * channel.
 */
export function channel_to_freq(band, channel) {
	if (band == '2G' && channel >= 1 && channel <= 13)
		return 2407 + channel * 5;
	else if (band == '2G' && channel == 14)
		return 2484;
	else if (band == '5G' && channel >= 7 && channel <= 177)
		return 5000 + channel * 5;
	else if (band == '5G' && channel >= 183 && channel <= 196)
		return 4000 + channel * 5;
	else if (band == '60G' && channel >= 1 && channel <= 6)
		return 56160 + channel * 2160;

	return null;
};

/**
 * Convert the unique sysfs path describing a wireless PHY to
 * the corresponding UCI section name
 *
 * @param {string} path
 *
 * @returns {string|false}
 * Returns the UCI section name of a specific PHY
 */
export function path_to_section(path) {
	let sid = null;

	cursor.load("wireless");
	cursor.foreach("wireless", "wifi-device", (s) => {
		if (s.path == path && s.scanning != 1) {
			sid = s['.name'];

			return false;
		}
	});

	return sid;
};

/**
 * Get a list of all wireless PHYs for a specific wireless band
 *
 * @param {string} band
 *
 * @returns {object[]}
 * Returns an array of all wireless PHYs for a specific wireless
 * band.
 */
export function lookup_by_band(band) {
	let baseband = band;
	let ret = [];

	if (band in ['5G-lower', '5G-upper'])
		baseband = '5G';

	for (let path, phy in phys) {
		if (!(baseband in phy.band))
			continue;

		let phy_min_freq, phy_max_freq;

		if (phy.frequencies) {
			phy_min_freq = min(...phy.frequencies);
			phy_max_freq = max(...phy.frequencies);
		}
		else {
			/* NB: this code is superfluous once ubus call wifi phy reports
			       supported frequencies directly */

			let min_ch = max(min(...phy.channels), band_channels[band][0]),
			    max_ch = min(max(...phy.channels), band_channels[band][1]);

			phy_min_freq = channel_to_freq(baseband, min_ch);
			phy_max_freq = channel_to_freq(baseband, max_ch);

			if (phy_min_freq === null) {
				warn("Unable to map channel %d in band %s to frequency", min_ch, baseband);
				continue;
			}

			if (phy_max_freq === null) {
				warn("Unable to map channel %d in band %s to frequency", max_ch, baseband);
				continue;
			}
		}

		/* phy's frequency range does not overlap with band's frequency range, skip phy */
		if (phy_max_freq < band_freqs[band][0] || phy_min_freq > band_freqs[band][1])
			continue;

		let sid = path_to_section(path);

		if (sid)
			push(ret, { ...phy, section: sid });
	}

	return ret;
};

phys = lookup_phys();
