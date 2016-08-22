#!/usr/bin/env python3

import sys, urllib.request, json, ipaddress

URL_PREFIXES = 'http://nop.rnl.tecnico.ulisboa.pt/api/ipam/prefixes/'

if len(sys.argv) > 1:
    ip = sys.argv[1]
else:
    print('Usage: network <ip>')
    sys.exit()

response = urllib.request.urlopen(URL_PREFIXES)
prefixes = json.loads(response.read().decode('utf-8'))

for prefix in prefixes:
    if prefix['vlan'] != None:
        if ipaddress.ip_address(ip) in ipaddress.ip_network(prefix['prefix']):
            #print('%-30s %4d   %s' % (prefix['prefix'], int(prefix['vlan']['vid']), prefix['description']))
            print(prefix['description'].lower())
            sys.exit()

