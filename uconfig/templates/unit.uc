{%
	/* set the password */
	shell.password(unit.password);

	/* force the restart of the led script */
	if (exists(unit, 'leds_active'))
		services.set_enabled('led', 'restart');
-%}
# Configure the unit/system
set system.@system[-1].ttylogin={{ b(unit.tty_login) }}
{%	if (unit.name): %}
set system.@system[-1].description={{ s(unit.name) }}
{%	endif;
	if (unit.hostname): %}
set system.@system[-1].hostname={{ s(unit.hostname) }}
	endif;
	if (unit.location): %}
set system.@system[-1].notes={{ s(unit.location) }}
{%	endif;
	if (unit.timezone): %}
set system.@system[-1].timezone={{ s(unit.timezone) }}
{%	endif %}
set system.@system[-1].leds_off={{ b(!unit.leds_active) }}
