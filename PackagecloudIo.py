# apt-get install python-restkit

# https://packagecloud.io/docs/api
# http://benoitc.github.io/restkit/

from restkit import Resource, BasicAuth
from restkit import OAuthFilter, request
from restkit import util
import restkit.oauth2 as oauth

try:
    import simplejson as json
except ImportError:
    import json # py2.6 only


class PCBase(Resource):

    api_host = "packagecloud.io"
    api_url_base = "https://%s" % api_host

    def __init__(self, token, **kwargs):
        if getattr(self, 'api_url', None) is None:
            self.api_url = self.api_url_base
        self.token = token
        super(PCBase, self).__init__(
            self.api_url,
            filters = [BasicAuth(token, "")],
            follow_redirect=True,
            max_follow_redirect=10,
            **kwargs)
        
    def uri_str(self, path, params = {}):
        return util.make_uri(self.uri, path, charset=self.charset,
                             safe=self.safe, encode_keys=self.encode_keys,
                             **self.make_params(params))

    @property
    def distributions(self):
        return self.get_url('/api/v1/distributions.json')

    @property
    def repos(self):
        return [ RepoShowItem(self, r) \
                     for r in self.get_url('/api/v1/repos.json') ]

    #def repo_create(self, name, private):

    def repo_show(self, user=None, name=None, fqname=None):
        if fqname is None:
            fqname = '/'.join([user, name])
        return Repo(self, self.get_url('/api/v1/repos/%s' % fqname))

    def get_url(self, url):
        return json.loads(self.get(url).body_string())

class RepoShowItem(PCBase):

    def __init__(self, mgr, obj_dict):
        self.__dict__.update(obj_dict)
        self.mgr = mgr

    def repo(self):
        return self.mgr.repo_show(fqname=self.fqname)

    def prt(self):
        print "repo_show item %s:" % self.name
        print "    fqname:              %s" % self.fqname
        print "    created_at:          %s" % self.created_at
        print "    last_push_human:     %s" % self.last_push_human
        print "    package_count_human: %s" % self.package_count_human
        print "    private:             %s" % self.private

    def __repr__(self):
        return "<RepoShowItem %(fqname)s (%(package_count_human)s)>" % \
            self.__dict__


class Repo(PCBase):

    def __init__(self, mgr, obj_dict):
        self.__dict__.update(obj_dict)
        self.mgr = mgr
        self.api_url = "%s/api/v1/repos%s" % (mgr.api_url, self.path)
        super(Repo, self).__init__(mgr.token)

    def index(self, ptype, distro=None, version=None):
        uri = 'packages'
        for param in (ptype, distro, version):
            if param is not None:
                uri += "/%s" % param
            else:
                break
        uri += ".json"
        return [ Package(self, p) for p in self.get_url(uri) ]

    def all(self):
        uri = 'packages.json'
        return [ PackageVersion(self, p) for p in self.get_url(uri) ]

    def prt(self):
        print "repo %s:" % self.name
        print "    created_at:          %s" % self.created_at
        print "    updated_at:          %s" % self.updated_at

    def __repr__(self):
        return "<Repo %(name)s>" % self.__dict__

class Package(object):

    def __init__(self, repo, obj_dict):
        self.__dict__.update(obj_dict)
        # Extract arch from versions_url for this to be meaningful
        self.arch = self.versions_url.split('/')[-2]
        self.repo = repo
        self.mgr = repo.mgr

    def versions(self):
        return [ PackageVersion(self.repo, p) \
                     for p in self.mgr.get_url(self.versions_url) ]

    def prt(self):
        print "package %s:" % self.name
        print "    arch:           %s" % self.arch
        print "    versions_count: %s" % self.versions_count

    def __repr__(self):
        return "<Package %(name)s %(arch)s (%(versions_count)d versions)" % \
            self.__dict__

class PackageVersion(PCBase):

    def __init__(self, repo, obj_dict):
        self.__dict__.update(obj_dict)
        # Extract arch from versions_url for this to be meaningful
        self.arch = self.package_url.split('/')[-2]
        self.repo = repo
        self.mgr = repo.mgr
        self.api_url = self.package_url
        super(PackageVersion, self).__init__(self.mgr.token)

    def prt(self):
        print "package version %s:" % self.name
        print "    arch:           %s" % self.arch
        print "    distro_version: %s" % self.distro_version
        print "    version:        %s" % self.version
        print "    release:        %s" % self.release
        print "    created_at:     %s" % self.created_at
        print "    uploader_name:  %s" % self.uploader_name
        print "    filename:       %s" % self.filename

    def destroy(self):
        #DELETE /api/v1/repos/:user/:repo/:distro/:version/:package.:ext
        self.repo.delete('/%(distro_version)s/%(filename)s' % (self.__dict__))

    def __repr__(self):
        return "<Package %(distro_version)s %(name)s "\
            "%(version)s-%(release)s_%(arch)s>" % self.__dict__

