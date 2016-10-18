#!/usr/bin/python

import sys, os, re, argparse

from PackagecloudIo import PCBase
from pprint import pprint

import apt_pkg; apt_pkg.init_system()



parser = argparse.ArgumentParser(description='Prune packagecloud.io packages')
parser.add_argument('--filter', '-f', help="filter package names by regex")
parser.add_argument(
    '--keep-versions', '-k',
    type=int,
    default=int(os.getenv("PACKAGECLOUD_KEEP_VERSIONS",0)),
    help=("number of versions to keep; 0 keeps all (default); " \
          "also set with PACKAGECLOUD_KEEP_VERSIONS env. var."),
)
parser.add_argument(
    '--token', '-t',
    default=os.getenv("PACKAGECLOUD_TOKEN",None),
    help=("Packagecloud token; or set PACKAGECLOUD_TOKEN environment variable"),
)
parser.add_argument(
    '--user', '-u',
    default=os.getenv("PACKAGECLOUD_USER",None),
    help=("Packagecloud user; or set PACKAGECLOUD_USER environment variable"),
)
parser.add_argument(
    '--repo', '-r',
    default=os.getenv("PACKAGECLOUD_REPO",None),
    help=("Packagecloud repo; or set PACKAGECLOUD_REPO environment variable"),
)
args = parser.parse_args()

api = PCBase(args.token)
repo=api.repo_show(args.user, args.repo)
print "Packagecloud.io repo '%s'" % repo.name

def prune_old_versions(package):
    if int(package.versions_count) > args.keep_versions:
        print "Package %s arch %s:  %s version > %s max" % \
            (package.name, package.arch,
             package.versions_count, args.keep_versions)
        pvs = sorted(package.versions(),
                     cmp=apt_pkg.version_compare,
                     key=lambda pv: "%s-%s" % (pv.version, pv.release),
                     reverse=True)
        print "   Keeping:"
        for pv in (pvs[:args.keep_versions] if args.keep_versions else pvs):
            print "        %s" % pv.filename
        if args.keep_versions and pvs[args.keep_versions:]:
            print "   Removing:"
            for pv in pvs[args.keep_versions:]:
                print "        %s" % pv.filename
                if args.keep_versions:
                    pv.destroy()
        print
    else:
        print "Package %s arch %s:  %s version <= %s max" % \
            (package.name, package.arch,
             package.versions_count, args.keep_versions)

args.filter_re = re.compile(args.filter)
for p in repo.index('deb'):
    if args.filter_re.match(p.name) is None:
        print "Package %s arch %s:  filter not matched, skipping" % \
            (p.name, p.arch)
        continue
    prune_old_versions(p)

