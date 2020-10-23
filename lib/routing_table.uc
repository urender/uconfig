/**
 * @class uconfig.routing_table
 * @classdesc
 *
 * The routing table utility class allows querying system routing tables.
 */

/** @lends uconfig.routing_table.prototype */

'use strict';

let used_tables = {};
let next = 1;

/**
 * Allocate a route table index for the given ID
 *
 * @param {string} id  The ID to lookup or reserve
 * @returns {number} The table number allocated for the given ID
 */
export function get(id) {
	if (!this.used_tables[id])
		this.used_tables[id] = this.next++;
	return this.used_tables[id];
};

export function init() {
	used_tables = {};
	next = 1;
};
