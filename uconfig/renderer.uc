/* UCI batch output main script */

/**
 * @constructs
 * @name uconfig
 * @classdesc
 *
 * The uconfig namespace is not an actual class but merely a virtual
 * namespace for documentation purposes.
 *
 * From the perspective of a template author, the uconfig namespace
 * is the global root level scope available to embedded code, so
 * methods like `uconfig.b()` or `uconfig.info()` or utlity classes
 * like `uconfig.files` or `uconfig.wiphy` are available to templates
 * as `b()`, `info()`, `files` and `wiphy` respectively.
 */

"use strict";

global.topdir = sourcepath(0, true);

import * as fs from 'fs';
global.fs = fs;

import { uci } from 'uconfig.uci';
import { ubus } from 'uconfig.ubus';
import { capabilities } from 'uconfig.capabilities';
global.capabilities = capabilities;

import * as ethernet from 'uconfig.ethernet';
import * as routing_table from 'uconfig.routing_table';
import * as shell from 'uconfig.shell';
import * as wiphy from 'uconfig.wiphy';
import * as ipcalc from 'uconfig.ipcalc';

/**
 * Formats a given input value as uci boolean value.
 *
 * @memberof uconfig.prototype
 * @param {*} val The value to format
 * @returns {string}
 * Returns '1' if the given value is truish (not `false`, `null`, `0`,
 * `0.0` or an empty string), or `0` in all other cases.
 */
function b(val) {
	return val ? '1' : '0';
}

/**
 * Formats a given input value as single quoted string, honouring uci
 * specific escaping semantics.
 *
 * @memberof uconfig.prototype
 * @param {*} str The string to format
 * @returns {string}
 * Returns an empty string if the given input value is `null` or an
 * empty string. Returns the escaped and quoted string in all other
 * cases.
 */
function s(str) {
	if (str === null || str === '')
		return '';

	return sprintf("'%s'", replace(str, /'/g, "'\\''"));
}

/**
 * Attempt to include a file, catching potential exceptions.
 *
 * Try to include the given file path in a safe manner. The
 * path is resolved relative to the path of the currently
 * executed template and may only contain the character `A-Z`,
 * `a-z`, `0-9`, `_`, `/` and `-` as must contain a final
 * `.uc` file extension.
 *
 * Exception occuring while including the file are catched
 * and a warning is emitted instead.
 *
 * @memberof uconfig.prototype
 * @param {string} path Path of the file to include
 * @param {object} scope The scope to pass to the include file
 */
function tryinclude(path, scope) {
	if (!match(path, /^[A-Za-z0-9_\/-]+\.uc$/)) {
		warn("Refusing to handle invalid include path '%s'", path);
		return;
	}

	let parent_path = sourcepath(1, true);

	assert(parent_path, "Unable to determine calling template path");

	try {
		include(parent_path + "/" + path, scope);
	}
	catch (e) {
		warn("Unable to include path '%s': %s\n%s", path, e, e.stacktrace[0].context);
	}
}

let serial = uci.get("uconfig", "config", "serial");

export function generate(state, logs, scope) {
	logs = logs || [];

	ethernet.init();
	ipcalc.init();
	routing_table.init();

	/** @lends uconfig.prototype */
	return render('templates/toplevel.uc', {
		b,
		s,
		tryinclude,
		state,

		location: '/',
		serial,

		uci,
		ubus,
		ethernet,
		ipcalc,
		routing_table,
		shell,
		wiphy,
		
		...scope,

		/**
		 * Emit a warning message.
		 *
		 * @memberof uconfig.prototype
		 * @param {string} fmt  The warning message format string
		 * @param {...*} args	Optional format arguments
		 */
		warn: (fmt, ...args) => push(logs, sprintf("[W] (In %s) ", location || '/') + sprintf(fmt, ...args)),

		/**
		 * Emit an error message.
		 *
		 * @memberof uconfig.prototype
		 * @param {string} fmt  The warning message format string
		 * @param {...*} args   Optional format arguments
		 */
		error: (fmt, ...args) => push(logs, sprintf("[E] (In %s) ", location || '/') + sprintf(fmt, ...args)),

		/**
		 * Emit an informational message.
		 *
		 * @memberof uconfig.prototype
		 * @param {string} fmt  The information message format string
		 * @param {...*} args	Optional format arguments
		 */
		info: (fmt, ...args) => push(logs, sprintf("[!] (In %s) ", location || '/') + sprintf(fmt, ...args))
	});
};


