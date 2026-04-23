#!/usr/bin/env python3

import json
import os
import re
import subprocess
import sys
import tempfile


def ensure_ncclient_installed(allow_install):
    try:
        from ncclient import manager
        return manager
    except ImportError:
        if not allow_install:
            raise

        sys.stderr.write('ncclient not installed: attempting automatic install...\n')
        try:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', '--user', 'ncclient'])
        except subprocess.CalledProcessError as e:
            raise ImportError('ncclient is not installed and automatic installation failed') from e

        from ncclient import manager
        return manager

FILTERS = {
    'cisco_ios': '''
<filter>
  <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
    <banner/>
  </native>
</filter>
''',
    'cisco_xe': '''
<filter>
  <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
    <banner/>
  </native>
</filter>
''',
    'cisco_xr': '''
<filter>
  <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XR-sysadmin-cfg">
    <banner/>
  </native>
</filter>
''',
    'juniper_junos': '''
<filter>
  <configuration>
    <system>
      <login>
        <message/>
      </login>
    </system>
  </configuration>
</filter>
''',
    'generic': None
}

MESSAGE_DELIMITER = ']]>]]>'
DEFAULT_TIMEOUT = 30
DEFAULT_PORT = 830


def load_stdin_parameters():
    try:
        payload = sys.stdin.read()
        if not payload:
            return {}
        return json.loads(payload)
    except json.JSONDecodeError:
        return {}


def get_target_connection_params(stdin_params):
    target = stdin_params.get('_target') or {}
    if not isinstance(target, dict):
        return {}

    params = {
        'host': target.get('host') or target.get('uri'),
        'port': target.get('port'),
        'username': target.get('user'),
        'password': target.get('password'),
        'private_key': target.get('private-key'),
        'host_key_check': target.get('host-key-check')
    }

    netconf_config = target.get('netconf') if isinstance(target.get('netconf'), dict) else {}
    if netconf_config:
        params['port'] = params['port'] or netconf_config.get('port')
        params['password'] = params['password'] or netconf_config.get('password')
        params['private_key'] = params['private_key'] or netconf_config.get('private-key')
        params['host_key_check'] = params['host_key_check'] if params['host_key_check'] is not None else netconf_config.get('host-key-check')

    return {k: v for k, v in params.items() if v is not None}


def build_connection_parameters(stdin_params):
    target_params = get_target_connection_params(stdin_params)

    params = {
        'host': target_params.get('host') or stdin_params.get('host'),
        'port': int(target_params.get('port') or stdin_params.get('port') or DEFAULT_PORT),
        'username': target_params.get('username') or stdin_params.get('username'),
        'password': target_params.get('password') or stdin_params.get('password'),
        'private_key': target_params.get('private_key') or stdin_params.get('private_key'),
        'host_key_check': target_params.get('host_key_check') if target_params.get('host_key_check') is not None else stdin_params.get('host_key_check', True),
        'timeout': int(stdin_params.get('timeout', DEFAULT_TIMEOUT)),
        'device_type': stdin_params.get('device_type', 'generic'),
        'source': stdin_params.get('source', 'running'),
        'filter': stdin_params.get('filter'),
    'install_dependencies': bool(stdin_params.get('install_dependencies', True))
    }

    if not params['host']:
        raise ValueError('host is required either from _target or host parameter')
    if not params['username']:
        raise ValueError('username is required either from _target or username parameter')
    if not params['password'] and not params['private_key']:
        raise ValueError('password or private_key is required either from _target or password/private_key parameter')

    return params


def build_filter(device_type, custom_filter):
    if custom_filter:
        trimmed = custom_filter.strip()
        if trimmed.startswith('<filter'):
            return trimmed
        return f'<filter type="subtree">{trimmed}</filter>'

    return FILTERS.get(device_type)


def create_temporary_key_file(key_data):
    tmp = tempfile.NamedTemporaryFile(delete=False, mode='w', encoding='utf-8')
    tmp.write(key_data)
    tmp.close()
    return tmp.name


def extract_motd_text(xml_text):
    try:
        import xml.etree.ElementTree as ET
        root = ET.fromstring(xml_text)
        texts = []
        for node in root.iter():
            tag = node.tag.lower()
            if tag.endswith('banner') or tag.endswith('message'):
                if node.text and node.text.strip():
                    texts.append(node.text.strip())
        if texts:
            return '\n'.join(texts)
    except Exception:
        pass

    if 'banner' in xml_text.lower() or 'message' in xml_text.lower():
        return xml_text.strip()
    return None


def connect_and_get_motd(params):
    manager = ensure_ncclient_installed(params.get('install_dependencies', True))
    connect_args = {
        'host': params['host'],
        'port': params['port'],
        'username': params['username'],
        'timeout': params['timeout'],
        'hostkey_verify': bool(params['host_key_check']),
        'device_params': {'name': 'default'},
        'allow_agent': False,
        'look_for_keys': False
    }

    if params.get('password'):
        connect_args['password'] = params['password']

    key_file = None
    try:
        if params.get('private_key'):
            private_key = params['private_key']
            if isinstance(private_key, dict) and private_key.get('key-data'):
                key_file = create_temporary_key_file(private_key['key-data'])
                connect_args['key_filename'] = [key_file]
            elif isinstance(private_key, str):
                if os.path.exists(private_key):
                    connect_args['key_filename'] = [private_key]
                else:
                    key_file = create_temporary_key_file(private_key)
                    connect_args['key_filename'] = [key_file]

        with manager.connect(**connect_args) as m:
            filter_xml = build_filter(params['device_type'], params['filter'])
            if filter_xml:
                result = m.get_config(source=params['source'], filter=filter_xml)
            else:
                result = m.get_config(source=params['source'])

            xml_data = result.data_xml
            motd_text = extract_motd_text(xml_data)

            return {
                'host': params['host'],
                'device_type': params['device_type'],
                'source': params['source'],
                'motd_found': motd_text is not None,
                'motd_text': motd_text if motd_text is not None else '',
                'full_output': xml_data
            }

    finally:
        if key_file and os.path.exists(key_file):
            os.remove(key_file)


def main():
    try:
        stdin_params = load_stdin_parameters()
        parameters = build_connection_parameters(stdin_params)
        result = connect_and_get_motd(parameters)
        sys.stdout.write(json.dumps(result))
    except Exception as exc:
        error_output = {
            'error': str(exc)
        }
        sys.stderr.write(json.dumps(error_output))
        sys.exit(1)


if __name__ == '__main__':
    main()
