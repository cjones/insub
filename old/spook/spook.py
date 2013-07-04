#!/usr/bin/env python

from os.path import *
from collections import *
from functools import *
from itertools import *
import sys
import re
import os

spook_re = re.compile(r'^spook-(\w+)\.txt$', re.I)
not_alnum_re = re.compile(r'[^a-z0-9]', re.I)
esc_re = re.compile(r"([$@'%])")
esc = partial(esc_re.sub, r'\\\1')
clean = partial(not_alnum_re.sub, '')

def iterspookfiles():
    for basedir, subdirs, filenames in os.walk(dirname(abspath(__file__))):
        for filename in filenames:
            match = spook_re.search(filename)
            if match is not None:
                yield match.group(1), join(basedir, filename)


_spook_ordering = ['emacs', 'hugs', 'blog', 'prism']

def spook_ordering(item):
    try:
        idx = _spook_ordering.index(item[0])
    except ValueError:
        idx = len(_spook_ordering)
    return idx, item[0].lower()


def main():
    spook_files = sorted(iterspookfiles(), key=spook_ordering)
    seen = set()
    res = defaultdict(set)
    for key, file in spook_files:
        with open(file, 'rb') as fp:
            for line in fp:
                line = ' '.join(line.strip().split())
                if line:
                    ckey = clean(line.lower())
                    if ckey:
                        if ckey in seen:
                            print >> sys.stderr, 'DUPE in {}: {}'.format(key, line)
                        elif len(line) < 3:
                            print >> sys.stderr, 'SHORT line in {}: {}'.format(key, line)
                        else:
                            seen.add(ckey)
                            res[key].add(line)

    width = 78
    ident = ' ' * 4
    out = [['my @spook_lines = (']]
    for i, (key, lines) in enumerate(sorted(res.iteritems(), key=spook_ordering)):
        if i:
            out.append([])
        out.append(['{}# {}'.format(ident, key)])
        out.append([ident])
        for line in sorted(lines, key=lambda l: l.lower()):
            r = esc('"{}"'.format(line)) + ','
            plen = sum(imap(len, out[-1]))
            if plen + len(r) > width:
                out.append([ident])
            out[-1].extend([r, ' '])
    out = [''.join(c).rstrip() for c in out]
    out[-1] = out[-1].rstrip(',')
    out.append(');')
    print os.linesep.join(''.join(c) for c in out)

    return 0

if __name__ == '__main__':
    sys.exit(main())
