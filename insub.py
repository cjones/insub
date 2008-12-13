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

    @filter()
    def ver(self, lines):
        return lines

    @filter()
    def stdin(self, lines):
        return lines

    @filter()
    def execute(self, lines):
        return lines

    @filter()
    def slurp(self, lines):
        return lines

    @filter()
    def spook(self, lines):
        return lines

    @filter()
    def jive(self, lines):
        return lines

    @filter()
    def scramble(self, lines):
        return lines

    @filter()
    def leet(self, lines):
        return lines

    @filter()
    def reverse(self, lines):
        return lines

    @filter()
    def jigs(self, lines):
        return lines

    @filter()
    def sine(self, lines):
        return lines

    @filter()
    def diagonal(self, lines):
        return lines

    @filter()
    def popeye(self, lines):
        return lines

    @filter()
    def matrix(self, lines):
        return lines

    @filter()
    def figlet(self, lines):
        return lines

    @filter()
    def banner(self, lines):
        return lines

    @filter()
    def hug(self, lines):
        return lines

    @filter()
    def rotate(self, lines):
        return lines

    @filter()
    def wrap(self, lines):
        return lines

    @filter()
    def chalkboard(self, lines):
        return lines

    @filter()
    def checker(self, lines):
        return lines

    @filter()
    def cow(self, lines):
        return lines

    @filter()
    def flip(self, lines):
        return lines

    @filter()
    def outline(self, lines):
        return lines

    @filter()
    def rainbow(self, lines):
        return lines

    @filter()
    def tree(self, lines):
        return lines

    @filter()
    def blink(self, lines):
        return lines

    @filter()
    def ircii_fake(self, lines):
        return lines

    @filter()
    def ircii_drop(self, lines):
        return lines

    @filter()
    def prefix(self, lines):
        return lines

    @filter()
    def strip(self, lines):
        return lines


def main():
    # dest metavar default action type nargs const choices callback help
    # store[_(const|true|false)] append[_const] count callback
    # string int long float complex choice

    # add filter options to arg parser
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

    # process data
    insub = Insub(**opts.__dict__)
    print insub.process()

    return 0


if __name__ == '__main__':
    sys.exit(main())
