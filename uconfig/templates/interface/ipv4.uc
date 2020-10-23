{# setup the routing table if a vlan is used #}
{% if (interface.role == 'upstream' && ethernet.has_vlan(interface)): %}
set network.{{ name }}.ip4table={{ routing_table.get(this_vid) }}
{% endif %}
{# static proto needs an IP and gateway #}
{% if (ipv4_mode == 'static'): %}
set network.{{ name }}.ipaddr={{ ipv4.subnet }}
set network.{{ name }}.gateway={{ ipv4.gateway }}
{% else %}
{# DHCP proto can ignore the provided DNS #}
set network.{{ name }}.peerdns={{ b(!length(ipv4.use_dns)) }}
{% endif %}
{# add any additionally provided DNS servers #}
{%  for (let dns in ipv4.use_dns): %}
add_list network.{{ name }}.dns={{ dns }}
{%  endfor %}
