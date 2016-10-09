#!/usr/bin/python

import os

from PackagecloudIo import PCBase
from pprint import pprint

max_old_packages = int(os.getenv("PACKAGECLOUD_MAX_OLD_PACKAGES",0))
token = os.getenv("PACKAGECLOUD_TOKEN")
user = os.getenv("PACKAGECLOUD_USER")
repo = os.getenv("PACKAGECLOUD_REPO")

api = PCBase(token)
repo=api.repo_show(user, repo)
print "Packagecloud.io repo '%s'" % repo.name

def prune_old_versions(package):
    if int(package.versions_count) > max_old_packages:
        print "Package %s arch %s:  %s version > %s max" % \
            (package.name, package.arch,
             package.versions_count, max_old_packages)
        pvs = sorted(package.versions(),
                     key=lambda pv: pv.created_at,
                     reverse=True)
        print "   Keeping:"
        for pv in pvs[:max_old_packages]:
            print "        %s" % pv.filename
        print "   Removing:"
        for pv in pvs[max_old_packages:]:
            print "        %s" % pv.filename
            pv.destroy()
        print
    else:
        print "Package %s arch %s:  %s version <= %s max" % \
            (package.name, package.arch,
             package.versions_count, max_old_packages)

if max_old_packages > 0:
    for p in repo.index('deb'):
        prune_old_versions(p)
else:
    print "Set PACKAGECLOUD_MAX_OLD_PACKAGES to automatically prune packages"
