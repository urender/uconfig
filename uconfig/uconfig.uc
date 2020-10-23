'use strict';

let error = 0;
let logs = [];

import * as fs from 'fs';
import * as reader from 'ureader.schema';
import * as renderer from 'uconfig.renderer';
import * as files from 'uconfig.files';
import * as services from 'uconfig.services';

function generate(file, verbose, reload) {
	/* flush previous state */
	files.init();
	services.init();
	logs = [];

	/* read the input file */
	let cfgjson = files.read(file);

	/* remove some old files */
	for (let cmd in [ 'rm -rf /tmp/uconfig',
			  'mkdir /tmp/uconfig',
			  'rm -f /tmp/dnsmasq.conf',
			  'touch /tmp/dnsmasq.conf' ])
		system(cmd);

	/* validate the configuration */
	let state = reader.validate(cfgjson, logs);

	/* die if the reader failed to validate the config */
	if (!state)
		die(logs);

	/* generate the UCI batch sequence */
	let batch = renderer.generate(state, logs, { files, services });

	if (state.strict && length(logs)) {
		push(logs, 'Rejecting config due to strict-mode validation');
		state = null;
		verbose = true;
	}

	/* print some debug output */
	if (verbose) {
		fs.stdout.write('Log messages:\n' + join('\n', logs) + '\n\n');
		fs.stdout.write('UCI batch output:\n' + batch + '\n');
	}

	if (!state)
		return;

	/* write the UCI batch file */
	files.write('/tmp/uconfig.uci', batch);

	/* preapre the sanitized shadow config */
	for (let cmd in [ 'rm -rf /tmp/config-shadow',
			  'cp -r /etc/config-shadow /tmp' ])
		system(cmd);

	/* import the UCI batch file */
	files.popen('/sbin/uci -q -c /tmp/config-shadow batch', batch);

	/* write all dynamically generated files */
	files.generate(logs);

	/* disable all none used services */
	services.stop();

	/* copy generated shadow config to /etc/config/ and reload the configuration */
	for (let cmd in [ 'uci -q -c /tmp/config-shadow commit',
			  'cp /tmp/config-shadow/* /etc/config/',
			  'rm -rf /tmp/config-shadow' ])
		system(cmd);

	if (reload)
		system('reload_config');


	/* enable all used services */
	services.start();

	return logs;
}

return {
	generate
};
