#!/usr/bin/env python3

import json
import socket
import sys
import xml.etree.ElementTree as ET


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
        'host_key_check': target.get('host-key-check')
    }

    netconf_config = target.get('netconf') if isinstance(target.get('netconf'), dict) else {}
    if netconf_config:
        params['port'] = params['port'] or netconf_config.get('port')
        params['password'] = params['password'] or netconf_config.get('password')
        params['host_key_check'] = params['host_key_check'] if params['host_key_check'] is not None else netconf_config.get('host-key-check')

    return {k: v for k, v in params.items() if v is not None}


def build_connection_parameters(stdin_params):
    target_params = get_target_connection_params(stdin_params)

    params = {
        'host': target_params.get('host') or stdin_params.get('host'),
        'port': int(target_params.get('port') or stdin_params.get('port') or 830),
        'username': target_params.get('username') or stdin_params.get('username'),
        'password': target_params.get('password') or stdin_params.get('password'),
        'host_key_check': target_params.get('host_key_check') if target_params.get('host_key_check') is not None else stdin_params.get('host_key_check', True),
        'timeout': int(stdin_params.get('timeout', 30)),
        'device_type': stdin_params.get('device_type', 'generic'),
        'source': stdin_params.get('source', 'running'),
        'filter': stdin_params.get('filter')
    }

    if not params['host']:
        raise ValueError('host is required either from _target or host parameter')
    if not params['username']:
        raise ValueError('username is required either from _target or username parameter')
    if not params['password']:
        raise ValueError('password is required either from _target or password parameter')

    return params


def build_get_config_rpc(filter_xml=None):
    rpc = '<?xml version="1.0" encoding="UTF-8"?>\n'
    rpc += '<rpc xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="1">\n'
    rpc += '  <get-config>\n'
    rpc += '    <source><running/></source>\n'
    if filter_xml:
        rpc += f'    <filter type="subtree">{filter_xml}</filter>\n'
    rpc += '  </get-config>\n'
    rpc += '</rpc>\n'
    return rpc


def extract_motd_from_xml(xml_data):
    try:
        root = ET.fromstring(xml_data)
        texts = []
        for node in root.iter():
            tag = node.tag.lower()
            if 'banner' in tag or 'message' in tag or 'motd' in tag:
                if node.text and node.text.strip():
                    texts.append(node.text.strip())
        if texts:
            return '\n'.join(texts)
    except Exception:
        pass

    if 'banner' in xml_data.lower() or 'message' in xml_data.lower():
        return xml_data.strip()

    return None


def connect_netconf_ssh(host, port, username, password, timeout):
    try:
        import paramiko
    except ImportError:
        raise ImportError('paramiko is required for NETCONF SSH. Install with: pip install paramiko')

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(
            hostname=host,
            port=port,
            username=username,
            password=password,
            timeout=timeout,
            look_for_keys=False,
            allow_agent=False
        )
    except paramiko.AuthenticationException as e:
        raise ValueError(f'Authentication failed: {e}')
    except socket.timeout:
        raise TimeoutError(f'Connection timeout after {timeout}s')
    except Exception as e:
        raise RuntimeError(f'SSH connection failed: {e}')

    return client


def send_netconf_hello(channel):
    hello = '<?xml version="1.0" encoding="UTF-8"?>\n'
    hello += '<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">\n'
    hello += '  <capabilities>\n'
    hello += '    <capability>urn:ietf:params:netconf:base:1.0</capability>\n'
    hello += '  </capabilities>\n'
    hello += '</hello>\n'
    hello += ']]>]]>\n'

    channel.send(hello.encode('utf-8'))


def read_netconf_message(channel):
    data = b''
    while True:
        chunk = channel.recv(4096)
        if not chunk:
            raise RuntimeError('Connection closed by server - NETCONF subsystem may not be available on the device')
        data += chunk
        if b']]>]]>' in data:
            msg, _ = data.split(b']]>]]>', 1)
            return msg.decode('utf-8', errors='ignore')


def get_config_netconf(host, port, username, password, timeout, filter_xml=None):
    client = connect_netconf_ssh(host, port, username, password, timeout)

    try:
        transport = client.get_transport()
        channel = transport.open_session()
        channel.invoke_subsystem('netconf')

        send_netconf_hello(channel)
        server_hello = read_netconf_message(channel)

        rpc = build_get_config_rpc(filter_xml)
        channel.send((rpc + ']]>]]>\n').encode('utf-8'))

        config_response = read_netconf_message(channel)

        return config_response

    finally:
        client.close()


def main():
    try:
        stdin_params = load_stdin_parameters()
        params = build_connection_parameters(stdin_params)

        filter_xml = params.get('filter') or ''

        config_xml = get_config_netconf(
            params['host'],
            params['port'],
            params['username'],
            params['password'],
            params['timeout'],
            filter_xml
        )

        motd_text = extract_motd_from_xml(config_xml)

        result = {
            'host': params['host'],
            'device_type': params['device_type'],
            'source': params['source'],
            'motd_found': motd_text is not None,
            'motd_text': motd_text if motd_text is not None else '',
            'full_output': config_xml[:2000]
        }

        sys.stdout.write(json.dumps(result))

    except Exception as exc:
        error_output = {'error': str(exc)}
        sys.stderr.write(json.dumps(error_output))
        sys.exit(1)


if __name__ == '__main__':
    main()
