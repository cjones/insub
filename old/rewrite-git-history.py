#!/usr/bin/env python

"""Does what it says on the tin"""

import collections
import subprocess
import operator
import datetime
import textwrap
import numbers
import decimal
import shutil
import time
import glob
import sys
import os
import re

Release = collections.namedtuple('Release', ('path', 'date', 'changes', 'insub'))
Change = collections.namedtuple('Change', ('date', 'items'))
Commit = collections.namedtuple('Commit', ('id', 'date'))

version_re = re.compile(r'^gay-([0-9.]+)\.pl$')
change_version_re = re.compile(r'^([0-9.]+):?\s*(.+?)\s*$')
change_item_re = re.compile('^\s+(\*)?\s*(.+?)\s*$')

def run(*args, **kwargs):
    kwargs.setdefault('env', {})
    read = kwargs.pop('read', False)
    if read:
        kwargs.setdefault('stdout', subprocess.PIPE)
    write = kwargs.pop('write', None)
    if write:
        kwargs.setdefault('stdin', subprocess.PIPE)
    print '>>> ' + ' '.join(args)
    process = subprocess.Popen(args, **kwargs)
    try:
        if write:
            process.stdin.write(write)
            process.stdin.close()
        if read:
            return process.stdout.read()
    finally:
        if process.wait() != os.EX_OK:
            raise RuntimeError('%s exited with status: %d' % (args[0], process.returncode))


def git(*args, **kwargs):
    dir = kwargs.pop('dir', None)
    read = kwargs.pop('read', False)
    write = kwargs.pop('write', None)
    opts = {'env': kwargs, 'read': read, 'write': write}
    if dir:
        opts['cwd'] = dir
    return run('git', *args, **opts)


def get_releases(base_dir):
    dist_dir = os.path.join(base_dir, 'old')
    insub_dir = os.path.join(base_dir, os.pardir, 'insub')
    releases, changes = {}, {}

    for filename in os.listdir(dist_dir):
        match = version_re.search(filename)
        if match is not None:
            path = os.path.join(dist_dir, filename)
            releases[decimal.Decimal(match.group(1))] = Release(
                    path=path, date=datetime.datetime.fromtimestamp(os.stat(path).st_mtime), changes=None, insub=None)

    with open(os.path.join(base_dir, 'ChangeLog'), 'rb') as fp:
        state = {'version': None, 'date': None, 'items': []}
        for line in fp:
            line = line.rstrip('\r\n')
            match = change_version_re.search(line)
            if match is None:
                match = change_item_re.search(line)
                if match is None:
                    if line.strip():
                        raise ValueError('what the heck is this: %r' % line)
                else:
                    start_item, text = match.groups()
                    if start_item:
                        state['items'].append([])
                    state['items'][-1].append(text)
            else:
                if state['version'] is not None:
                    changes[state['version']] = Change(
                            date=state['date'], items=tuple(' '.join(item) for item in state['items']))
                version, date = match.groups()
                state['version'] = decimal.Decimal(version)
                try:
                    date = datetime.datetime.strptime(date.replace(' PDT', '').replace(' PST', ''), '%c')
                except ValueError:
                    date = None
                state['date'] = date
                state['items'][:] = []

    for version, release in releases.iteritems():
        change = changes.get(version)
        if change is None:
            change = Change(date=release.date, items=())
        elif change.date is None:
            change = change._replace(date=release.date)

        if change.date < release.date:
            release = release._replace(date=change.date)
        insubs = map(os.path.abspath, glob.glob(os.path.join(insub_dir, 'insub-%s.*' % version)))
        releases[version] = release._replace(changes=change.items, insub=sorted(insubs)[0] if insubs else None)

    return releases


def make_git_commit_date(commit_date=None):
    if commit_date is None:
        commit_date = datetime.datetime.now()
    if not isinstance(commit_date, numbers.Number):
        if not isinstance(commit_date, datetime.date):
            raise TypeError('commit date must be a datetime or date object')
        tt = commit_date.timetuple()
        commit_date = time.mktime(tt)
    commit_date = '%d -0700' % int(round(commit_date))
    return commit_date


def create_initial_commit(repos_dir, commit_date=None, commit_message=None,
                          dummy_file=None, author_name=None, author_email=None):
    commit_date = make_git_commit_date(commit_date)

    if commit_message is None:
        commit_message = 'initial commit'

    _git = lambda *args, **kwargs: git(*args, **dict(kwargs, dir=repos_dir))

    _git('symbolic-ref', 'HEAD', 'refs/heads/newroot')
    _git('rm', '--cached', '-r', '.')
    _git('clean', '-f', '-d')

    if dummy_file:
        if os.path.isabs(dummy_file):
            parts = dummy_file.split(os.sep)
            while parts and not parts[0]:
                parts.pop(0)
            dummy_file = os.path.join(*parts)

        local_dummy_file = os.path.join(repos_dir, dummy_file)
        local_dummy_dir = os.path.dirname(local_dummy_file)
        if not os.path.exists(local_dummy_dir):
            raise RuntimeError('cannot create ' + local_dummy_file)

        if os.path.exists(local_dummy_file):
            raise RuntimeError('already exists in repository, or working dir not clean: ' + local_dummy_file)
        open(local_dummy_file, 'wb').close()
        _git('add', dummy_file)

    _git('commit', '--allow-empty', '-m', commit_message,
            GIT_AUTHOR_NAME=author_name,
            GIT_AUTHOR_EMAIL=author_email,
            GIT_AUTHOR_DATE=commit_date,
            GIT_COMMITTER_NAME=author_name,
            GIT_COMMITTER_EMAIL=author_email,
            GIT_COMMITTER_DATE=commit_date,
            EMAIL=author_email)

    _git('rebase', '--onto', 'newroot', '--root', 'master')
    rootid = _git('show-ref', '--verify', '-s', 'refs/heads/newroot', read=True).strip()
    _git('branch', '-d', 'newroot')
    return rootid


def main():
    release_dir = '/data/docroot/gruntle.org/projects/irssi/gay'
    repos_dir = '/home/cjones/migrate-github/remote/test'
    author_name = 'Chris Jones'
    author_email = 'cjones@gmail.com'
    target_subdir = 'old'

    cow_dir = os.path.join(release_dir, 'cows')

    releases = get_releases(release_dir)
    releases = sorted(releases.iteritems(), key=operator.itemgetter(0))
    first_version, first_release = releases[0]

    create_initial_commit(
            repos_dir,
            commit_date=first_release.date - datetime.timedelta(minutes=5),
            commit_message='initial commit',
            dummy_file='.gitignore',
            author_name=author_name,
            author_email=author_email,
            )

    commits = []
    for log in git('log', '--pretty=tformat:%H %at', dir=repos_dir, read=True).strip().splitlines():
        commit_id, commit_date = log.split()
        commits.append(Commit(commit_id, datetime.datetime.fromtimestamp(int(commit_date))))

    _git = lambda *args, **kwargs: git(*args, **dict(kwargs, dir=repos_dir))

    tag_re = re.compile(r'<.*?>', re.DOTALL)
    with open(os.path.join(release_dir, 'README.html'), 'rb') as fp:
        readme = fp.read()
        readme = tag_re.sub('', readme)
        readme = readme.replace('&lt;', '<')
        readme = readme.replace('&gt;', '>')
        readme = '\n'.join(line.rstrip() for line in readme.strip().splitlines()) + '\n'

    changelog = []
    wrapper = textwrap.TextWrapper(width=80 - 6, initial_indent='    * ', subsequent_indent='      ')

    for version, release in releases:
        cl = ['%s: %s' % (version, release.date.strftime('%c'))]
        for item in release.changes:
            cl.extend(wrapper.wrap(item))
        if changelog:
            changelog.insert(0, '')
        changelog[:] = cl + changelog[:]
        change_text = '\n'.join(changelog) + '\n'

        tmp = sorted(commits[:] + [release], key=operator.attrgetter('date'))
        parent = tmp[tmp.index(release) - 1].id

        _git('checkout', '-b', 'new_commit', parent)

        files = []

        def add(_rel_path, path=None, data=None):
            rel_path = os.path.join(target_subdir, _rel_path)
            local_path = os.path.join(repos_dir, rel_path)
            local_dir = os.path.dirname(local_path)
            if not os.path.exists(local_dir):
                os.makedirs(local_dir)
            if path:
                shutil.copy2(path, local_path)
            elif data:
                with open(local_path, 'wb') as fp:
                    fp.write(data)
            files.append(rel_path)

        add(os.path.join('dist', os.path.basename(release.path)), path=release.path)
        add('gay.pl', path=release.path)
        add('ChangeLog', data=change_text)
        if release.insub:
            add(os.path.join('insub', os.path.basename(release.insub)), path=release.insub)

        if release is first_release:
            for filename in os.listdir(cow_dir):
                cowpath = os.path.join(cow_dir, filename)
                add(os.path.join('cows', filename), path=cowpath)

            add('README', data=readme)
            add('rewrite-git-history.py', path=__file__)

        commit_date = make_git_commit_date(release.date)

        _git('add', *files)
        _git('commit', '-m', 'released version %s' % version,
                GIT_AUTHOR_NAME=author_name,
                GIT_AUTHOR_EMAIL=author_email,
                GIT_AUTHOR_DATE=commit_date,
                GIT_COMMITTER_NAME=author_name,
                GIT_COMMITTER_EMAIL=author_email,
                GIT_COMMITTER_DATE=commit_date,
                EMAIL=author_email)

        _git('checkout', 'master')
        _git('rebase', 'new_commit')
        commit_id = _git('show-ref', '--verify', '-s', 'refs/heads/new_commit', read=True).strip()
        _git('branch', '-d', 'new_commit')

        commits.append(Commit(commit_id, release.date))

        def add_tag(name):
            tagname = '%s-%s' % (name, version)
            tag = '\n'.join(['object ' + commit_id,
                            'type commit',
                            'tag ' + tagname,
                            'tagger %s <%s> %s' % (author_name, author_email, commit_date),
                            '',
                            'Tagged release ' + tagname]) + '\n'

            tag_id = _git('mktag', write=tag, read=True).strip()
            _git('update-ref', 'refs/tags/' + tagname, tag_id, '')

        add_tag('gay')
        if release.insub:
            add_tag('insub')

    return 0

if __name__ == '__main__':
    sys.exit(main())
