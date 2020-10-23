{# setup the routing table if a vlan is used #}
{% if (interface.role == 'upstream' && ethernet.has_vlan(interface)): %}
set network.{{ name }}.ip6table={{ routing_table.get(this_vid) }}
{% endif %}
{# static proto needs an IP and gateway #}
{% if (ipv6_mode == 'static'): %}
set network.{{ name }}.ip6addr={{ ipv6.subnet }}
set network.{{ name }}.ip6gw={{ ipv6.gateway }}
set network.{{ name }}.ip6assign={{ ipv6.prefix_size || '64' }}
{% else %}
set network.{{ name }}.reqprefix={{ ipv6.prefix_size || 'auto' }}
{% endif %}
