#!/usr/bin/env python
#
# Copyright (c) 2008, Chris Jones
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials provided
#    with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

"""Suite of text filters"""

import sys
from optparse import OptionParser

__version__ = '0.1'
__author__ = 'Chris Jones <cjones@gruntle.org>'
__all__ = ['Insub']

class Insub(object):

    """Suite of text filters"""

    def __init__(self, **opts):
        self.__dict__.update(opts)

    def process(self, data):
        lines = data.splitlines()
        for filter in self.filters:
            lines = filter(self, lines)
        return '\n'.join(lines)

    class filter(object):

        filters = []

        def __init__(self, **options):
            self.options = options

        def __call__(self, func):
            self.__class__.filters.append((func, self.options))
            return func


def main():
    # dest metavar default action type nargs const choices callback help
    # store[_(const|true|false)] append[_const] count callback
    # string int long float complex choice
    parser = OptionParser(version=__version__)
    filters = []
    add_filter = lambda option, key, val, parser, func: filters.append(func)
    for func, options in Insub.filter.filters:
        parser.add_option('--' + func.__name__, action='callback',
                          callback=add_filter, callback_args=(func,),
                          help=func.__doc__)
        for option, kwargs in options.iteritems():
            parser.add_option('--' + option, **kwargs)
    opts, args = parser.parse_args()

    # put in their natural order
    opts.filters = []
    for func, options in Insub.filter.filters:
        if func in filters and func not in opts.filters:
            opts.filters.append(func)

    insub = Insub(**opts.__dict__)

    return 0


if __name__ == '__main__':
    sys.exit(main())
