#!/usr/bin/env python3
import os
import json
import sys

required = [
    'VLESS_SERVER_HOST',
    'VLESS_SERVER_PORT',
    'VLESS_UUID',
    'VLESS_PUBLIC_KEY',
    'VLESS_SHORT_ID'
]
for key in required:
    if key not in os.environ:
        raise SystemExit(f'Missing environment variable {key}')

config = {
    'log': {'loglevel': 'warning'},
    'inbounds': [{
        'type': 'tun',
        'interface_name': 'utun'
    }],
    'outbounds': [{
        'type': 'vless',
        'tag': 'out',
        'server': os.environ['VLESS_SERVER_HOST'],
        'server_port': int(os.environ['VLESS_SERVER_PORT']),
        'uuid': os.environ['VLESS_UUID'],
        'flow': 'xtls-rprx-vision',
        'packet_encoding': 'xudp',
        'security': 'reality',
        'reality-opts': {
            'public_key': os.environ['VLESS_PUBLIC_KEY'],
            'short_id': os.environ['VLESS_SHORT_ID']
        }
    }]
}

output = sys.argv[1] if len(sys.argv) > 1 else 'ios/Shared/config.json'
with open(output, 'w') as f:
    json.dump(config, f)
print(f'Config written to {output}')
