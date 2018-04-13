#!/bin/env python
# -*- coding: utf-8 -*-

import argparse
import json
import os
import re
import urllib.request
import shutil
import subprocess

PATH_WORK = 'opt'
PATH_DEPOT_TOOLS = 'opt/depot_tools'

# Change directory by ROOT_PATH.
def util_cd(*path):
    abs_path = util_getpath(*path)
    if not os.path.exists(abs_path):
        os.mkdir(abs_path)
    os.chdir(abs_path)
    print('cd : ' + abs_path)

def util_cp(src, dst):
    shutil.copy(src, dst)
    print('cp : ' + src + ' ' + dst)

def util_emptydir(*path):
    abs_path = util_getpath(*path)
    if os.path.exists(abs_path):
        shutil.rmtree(abs_path)
    os.mkdir(abs_path)
    print('mkdir : ' + abs_path)

def util_exec(*cmds):
    print('exec : ' + ' '.join(cmds))
    ret = subprocess.call(cmds)

def util_getpath(*path):
    global PATH_ROOT
    return os.path.join(PATH_ROOT, *path)

def util_mv(src, dst):
    shutil.move(src, dst)
    print('mv : ' + src + ' ' + dst)

# Parser for arguments.
def parse_args():
    parser = argparse.ArgumentParser(description='This script is ...')
    parser.add_argument('-c', '--configure', action='store',
                        default='config.json', type=str,
                        help="Set configuration json file name. 'default: config.json'")
    parser.add_argument('-t', '--target_env', action='store',
                        type=str, required=True,
                        choices=['osx'],
                        help="Set target envrionment.")
    parser.add_argument('--chrome_ver', action='store',
                        type=int, help="Set build target Chrome version.")
    parser.add_argument('-d', '--debug', action='store_true')

    return parser.parse_args()

#
def get_last_chrome_ver(os):
    csv = urllib.request.urlopen('https://omahaproxy.appspot.com/all').read()
    for line in csv.decode('utf-8').split('\n'):
        m = re.search(os + ',stable,([0-9]+)\.', line)
        if m:
            return int(m.group(1))

#
def get_work_path(conf, *path):
    path = conf['target_env']
    return util_getpath(PATH_WORK, path)

#
def get_archive_name(conf):
    name = conf['archive_name']
    for key, val in conf.items():
        name = name.replace('{' + key + '}', str(val))
    return name

# Parser for configuration file.
def parse_conf(args):
    # Load configuration file as JSON.
    fd_js = open(args.configure, 'r')
    js_all = json.load(fd_js)
    fd_js.close()

    # Get configuration for target environment.
    target_env = args.target_env
    js_env = js_all[target_env]

    # Check chrome version
    if args.chrome_ver is None:
        chrome_ver = get_last_chrome_ver(js_all['chrome_os_map'][target_env])
    else:
        chrome_ver = int(args.chrome_ver)

    # Merge envrionment values.
    conf = {}
    for it_env in js_env:
        # Conditions of skip filter
        if it_env['chrome_version'] > chrome_ver:
            continue
        # Mearge
        conf.update(it_env)

    conf['target_env'] = target_env
    conf['chrome_version'] = chrome_ver
    conf['debug'] = args.debug
    return conf

#
def setup(conf):
    # Update or get depot tools.
    if os.path.exists(util_getpath(PATH_DEPOT_TOOLS)):
        util_cd(PATH_DEPOT_TOOLS)
        util_exec('git', 'pull')
    else:
        util_exec('git', 'clone',
                  'https://chromium.googlesource.com/chromium/tools/depot_tools.git',
                  util_getpath(PATH_DEPOT_TOOLS))

    # Add path of depot tools for environment value PATH.
    os.environ['PATH'] = util_getpath(PATH_DEPOT_TOOLS) + ':' + os.environ['PATH']

#
def build(conf):
    work_path = get_work_path(conf)
    util_cd(work_path)
    util_exec('fetch', '--nohooks', 'webrtc')
    util_exec('gclient', 'sync', '--nohooks', '--with_branch_heads', '-v', '-R')
    # TODO install-build-deps.sh
    util_exec('git', 'submodule', 'foreach',
              "'git config -f $toplevel/.git/config submodule.$name.ignore all'")
    util_exec('git', 'config', '--add', 'remote.origin.fetch', "'+refs/tags/*:refs/tags/*'")
    util_exec('git', 'config', 'diff.ignoreSubmodules', 'all')

    util_cd(work_path, 'src')
    util_exec('git', 'fetch', 'origin')
    util_exec('git', 'checkout', '-B', str(conf['chrome_version']),
              'refs/remotes/branch-heads/' + str(conf['chrome_version']))
    util_exec('gclient', 'sync', '--with_branch_heads', '-v', '-R')
    util_exec('gclient', 'runhooks', '-v')
    if conf['debug']:
        util_exec('gn', 'gen', 'out/Default', '--args="is_debug=true"')
    else:
        util_exec('gn', 'gen', 'out/Default')
    util_exec('ninja', '-C', 'out/Default', conf['build_target'])

def archive(conf):
    work_path = get_work_path(conf)
    # Make directory
    util_emptydir(work_path, 'lib')
    util_emptydir(work_path, 'include')
    util_emptydir(work_path, 'include/webrtc')
    util_cd(work_path, 'src/out/Default')

    target_string = None
    for line in  open(conf['ninja_file'], 'r'):
        if line.find(conf['ninja_target']) >= 0:
            target_string = line
            break

    objs = []
    for obj in target_string.split(' '):
        for ex in conf['exclude_objs']:
            if obj.find(ex) >= 0:
                # Exclude files.
                continue
            elif re.search(r'\.o$', obj):
                # Collect *.o files.
                objs.append(obj)
            elif re.search(r'\.a$', obj):
                # Copy *.a files.
                util_cp(util_getpath(work_path, 'src/out/Default', obj), util_getpath(work_path, 'lib'))
    # Generate libwebrtc.a from *.o files.
    util_exec('ar', 'cr', util_getpath(work_path, 'lib/libwebrtc.a'), *objs)

    # Rename if needed.
    for src, dst in conf['rename_objs'].items():
        util_mv(util_getpath(work_path, 'lib', src), util_getpath(work_path, 'lib', dst))

    # Listup lib filenames.
    util_cd(work_path, 'lib')
    fd = open(util_getpath(work_path, 'exports_libwebrtc.txt'), 'w')
    fd.write("\n".join([f.name for f in os.scandir() if f.name.startswith('lib')]))
    fd.close()

    # Copy header files.
    util_cd(work_path, conf['header_root_path'])
    util_exec('find', '.', '-name', '*.h', '-exec', 'rsync', '-R', '{}', util_getpath(work_path, 'include/webrtc'), ';')

    # Archive
    util_cd(work_path)
    util_exec('zip', '-r', get_archive_name(conf), 'lib', 'include', 'exports_libwebrtc.txt')

if __name__ == '__main__':
    global PATH_ROOT
    PATH_ROOT = os.path.dirname(os.path.abspath(__file__))

    args = parse_args()
    conf = parse_conf(args)
    setup(conf)
    build(conf)
    archive(conf)
