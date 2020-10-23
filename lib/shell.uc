/**
 * @class uconfig.shell
 * @classdesc
 *
 * The shell utility class provides high level abstractions for various
 * shell interaction tasks.
 */

/** @lends uconfig.shell.prototype */

/**
 * Set the root password.
 *
 * Generate a static or random password or remove the root password,
 */
export function password(password) {
	if (type(password) != 'string')
		switch(password) {
		case true:
			let math = require("math");
			password = '';
			for (let i = 0; i < 32; i++) {
				let r = math.rand() % 62;
				if (r < 10)
					password += r;
			else if (r < 36)
					password += sprintf("%c", 55 + r);
				else
					password += sprintf("%c", 61 + r);
			}
			break;

		case null:
		case false:
			system('passwd -d root');
			return;
		}

	system("(echo " + password + "; sleep 1; echo " + password + ") | passwd root");
};
