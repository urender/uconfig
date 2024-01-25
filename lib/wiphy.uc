'use strict';

import * as fs from 'fs';
import * as uci from 'uci';
import * as nl from 'nl80211';

let cursor = uci ? uci.cursor() : null;
let paths = {};
let board = json(fs.readfile('/etc/board.json'));

export let phys = [];

function lookup_phys() {
	for (let phy, data in board?.wlan) {
		if (!data.info)
			continue;
		for (let k, v in data.info.bands) {
			let p = {
				phy,
				band: [ k ],
				rx_ant: data.info.antenna_rx,
				tx_ant: data.info.antenna_tx,
			};
			if (v.he)
				p.htmode = [ "HT20", "HT40", "VHT20", "VHT40", "VHT80", "HE20", "HE40", "HE80", 'HE160' ];
			else
				p.htmode = [ "HT20", "HT40" ];
			push(phys, p);
		}
	}
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
export function phy_to_section(phy) {
	let sid = null;

	cursor.load("wireless");
	cursor.foreach("wireless", "wifi-device", (s) => {
		if (s.phy == phy && s.scanning != 1) {
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

	for (let idx, phy in phys) {
		if (!(baseband in phy.band))
			continue;
		let sid = phy_to_section(phy.phy);
		if (sid)
			push(ret, { ...phy, section: sid });
	}

	return ret;
};

lookup_phys();
