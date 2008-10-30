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
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the
#    distribution.
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

from __future__ import with_statement
import sys
import re
import optparse
import subprocess
import shlex
import random

# defaults
SPOOKSIZE = 6

# default encodings
INPUT_ENCODING = OUTPUT_ENCODING = sys.getdefaultencoding()
if sys.stdin.encoding:
    INPUT_ENCODING = sys.stdin.encoding
if sys.stdout.encoding:
    OUTPUT_ENCODING = sys.stdin.encoding

OPTIONS = []
SPOOKWORDS = ('$400 million in gold bullion',
              '[Hello to all my fans in domestic surveillance]', 'AK-47',
              'ammunition', 'arrangements', 'assassination', 'BATF', 'bomb',
              'CIA', 'class struggle', 'Clinton', 'Cocaine', 'colonel',
              'counter-intelligence', 'cracking', 'Croatian', 'cryptographic',
              'Delta Force', 'DES', 'domestic disruption', 'explosion', 'FBI',
              'FSF', 'fissionable', 'Ft. Bragg', 'Ft. Meade', 'genetic',
              'Honduras', 'jihad', 'Kennedy', 'KGB', 'Khaddafi', 'kibo',
              'Legion of Doom', 'Marxist', 'Mossad', 'munitions', 'Nazi',
              'Noriega', 'North Korea', 'NORAD', 'NSA', 'nuclear', 'Ortega',
              'Panama', 'Peking', 'PLO', 'plutonium', 'Qaddafi', 'quiche',
              'radar', 'Rule Psix', 'Saddam Hussein', 'SDI', 'SEAL Team 6',
              'security', 'Semtex', 'Serbian', 'smuggle', 'South Africa',
              'Soviet ', 'spy', 'strategic', 'supercomputer', 'terrorist',
              'Treasury', 'Uzi', 'Waco, Texas', 'World Trade Center',
              'Liberals', 'Cheney', 'Eggs', 'Libya', 'Bush',
              'Kill the president', 'GOP', 'Republican', 'Shiite', 'Muslim',
              'Chemical Ali', 'Ashcroft', 'Terrorism', 'Al Qaeda',
              'Al Jazeera', 'Hamas', 'Israel', 'Palestine', 'Arabs', 'Arafat',
              'Patriot Act', 'Voter Fraud', 'Punch-cards', 'Diebold',
              'conspiracy', 'Fallujah', 'IndyMedia', 'Skull and Bones',
              'Free Masons', 'Kerry', 'Grass Roots', '9-11',
              'Rocket Propelled Grenades', 'Embedded Journalism',
              'Lockheed-Martin', 'war profiteering', 'Kill the President',
              'anarchy', 'echelon', 'nuclear', 'assassinate', 'Roswell',
              'Waco', 'World Trade Center', 'Soros', 'Whitewater', 'Lebed',
              'HALO', 'Spetznaz', 'Al Amn al-Askari', 'Glock 26',
              'Steak Knife', 'Rewson', 'SAFE', 'Waihopai', 'ASPIC', 'MI6',
              'Information Security', 'Information Warfare', 'Privacy',
              'Information Terrorism', 'Terrorism', 'Defensive Information',
              'Defense Information Warfare', 'Offensive Information',
              'Offensive Information Warfare', 'Ortega Waco', 'assasinate',
              'National Information Infrastructure', 'InfoSec',
              'Computer Terrorism', 'DefCon V', 'Encryption', 'Espionage',
              'NSA', 'CIA', 'FBI', 'White House', 'Undercover', 'Compsec 97',
              'Europol', 'Military Intelligence', 'Verisign', 'Echelon',
              'Ufologico Nazionale', 'smuggle', 'Bletchley Park',
              'Clandestine', 'Counter Terrorism Security',
              'Enemy of the State', '20755-6000', 'Electronic Surveillance',
              'Counterterrorism', 'eavesdropping', 'nailbomb',
              'Satellite imagery', 'subversives', 'World Domination',
              'wire transfer', 'jihad', 'fissionable', "Sayeret Mat'Kal",
              'HERF pipe-bomb', '2.3 Oz.  cocaine')

FLIPTRANS = {8255: 8256, 8261: 8262, 33: 161, 34: 8222, 38: 8523, 39: 44,
             40: 41, 41: 40, 46: 729, 51: 400, 52: 5421, 54: 57, 55: 11362,
             8756: 8757, 59: 1563, 60: 62, 63: 191, 65: 8704, 67: 8579,
             68: 9686, 69: 398, 70: 8498, 71: 8513, 74: 383, 75: 8906,
             76: 8514, 77: 87, 78: 7438, 80: 1280, 81: 908, 82: 7450,
             84: 8869, 85: 8745, 86: 7463, 89: 8516, 91: 93, 95: 8254,
             97: 592, 98: 113, 99: 596, 100: 112, 101: 477, 102: 607,
             103: 387, 104: 613, 105: 305, 106: 638, 107: 670, 108: 643,
             109: 623, 110: 117, 114: 633, 116: 647, 118: 652, 119: 653,
             121: 654, 123: 125}


def filter(*args, **kwargs):

    def decorator(func):

        def inner(*args, **kwargs):
            return func(*args, **kwargs)

        inner.__doc__ = func.__doc__
        inner.__name__ = func.__name__
        OPTIONS.append((inner.func_name, inner, kwargs))
        return inner

    return decorator


class Insub(object):

    def __init__(self, data, filters, **opts):
        self.data = data
        self.filters = filters
        self.__dict__.update(opts)

    @property
    def result(self):
        """Yields each line of filtered output"""
        lines = self.lines
        for filter in self.filters:
            lines = filter(self, lines)
        for line in lines:
            yield line

    @property
    def lines(self):
        """Yields each line of unfiltered output"""
        lines = self.data.splitlines()
        if not lines:
            lines = [u'']
        for line in lines:
            yield line

    # these filters control where text comes from

    @filter()
    def execute(self, lines):
        """Execute args and return output"""
        for line in lines:
            process = subprocess.Popen(shlex.split(line),
                                       stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT)
            for line in process.stdout.readlines():
                yield line.rstrip()

    @filter()
    def slurp(self, lines):
        """Read data from file"""
        for line in lines:
            for arg in shlex.split(line):
                with open(arg, 'r') as file:
                    for line in file.readlines():
                        line = line.rstrip()
                        yield line.decode(sys.sys.getdefaultencoding(),
                                          'replace')

    @filter(spooksize=dict(metavar='<#>', default=SPOOKSIZE, type='int',
                           help='How many words to insert with --spook'))
    def spook(self, lines):
        """Inject NSA foiling noise"""
        for line in lines:
            words = random.sample(SPOOKWORDS, self.spooksize)
            yield '%s %s' % (' '.join(words), line)

    @filter()
    def uniflip(self, lines):
        """Unicode flip"""
        for line in self.mirror(lines):
            yield line.translate(FLIPTRANS)

    @filter()
    def flip(self, lines):
        for line in reversed(list(lines)):
            yield line

    @filter()
    def jive(self, lines):
        """"""

    @filter()
    def scramble(self, lines):
        """"""

    @filter()
    def leet(self, lines):
        """"""

    @filter()
    def mirror(self, lines):
        """Reverse lines left-to-right"""
        lines = list(lines)
        size = max(map(len, lines))
        for line in lines:
            line = ''.join(reversed(line))
            yield (' ' * (size - len(line))) + line

    @filter()
    def jigs(self, lines):
        """"""

    @filter()
    def sine(self, lines):
        """"""

    @filter()
    def diagonal(self, lines):
        """"""

    @filter()
    def popeye(self, lines):
        """"""

    @filter()
    def matrix(self, lines):
        """"""

    @filter()
    def figlet(self, lines):
        """"""

    @filter()
    def banner(self, lines):
        """"""

    @filter()
    def hug(self, lines):
        """"""

    @filter()
    def rotate(self, lines):
        """"""

    @filter()
    def gwrap(self, lines):
        """"""

    @filter()
    def chalkboard(self, lines):
        """"""

    @filter()
    def cowsay(self, lines):
        """"""

    @filter()
    def upside_down(self, lines):
        """"""

    @filter()
    def checker(self, lines):
        """"""

    @filter()
    def outline(self, lines):
        """"""

    @filter()
    def rainbow(self, lines):
        """"""

    @filter()
    def tree(self, lines):
        """"""

    @filter()
    def blink(self, lines):
        """"""

    @filter()
    def ircii_fake(self, lines):
        """"""

    @filter()
    def ircii_drop(self, lines):
        """"""

    @filter()
    def strip(self, lines):
        """"""

    def __iter__(self):
        return self.lines

    def __repr__(self):
        return '<%s object at 0x%x: %s>' % (self.__class__.__name__, id(self),
                                            self.__dict__)


def main():
    parser = optparse.OptionParser()

    # encodings
    # dest metavar default action type nargs const choices callback help
    parser.add_option('--input-encoding', metavar='<charset>',
                      default=INPUT_ENCODING,
                      help='encoding of input (default: %default)')
    parser.add_option('--output-encoding', metavar='<charset>',
                      default=OUTPUT_ENCODING,
                      help='encoding of output (default: %default)')

    # callbacks

    filter_names = []

    def add_filter(option, key, val, parser, name):
        if name not in filter_names:
            filter_names.append(name)

    # add filters to option parser
    for name, func, kwargs in OPTIONS:
        parser.add_option('--' + name, action='callback', callback=add_filter,
                          callback_args=(name,), help=func.__doc__)
        for key, val in kwargs.items():
            parser.add_option('--' + key, **val)

    # parse argv
    opts, args = parser.parse_args()
    if len(args) == 1 and args[0] == '-':
        data = ''.join(sys.stdin.read())
    else:
        data = ' '.join(args)
    data = data.decode(opts.input_encoding)

    # sort filters by natural order
    filters = []
    for name, func, kwargs in OPTIONS:
        if name in filter_names:
            filters.append(func)

    # process
    i = Insub(data, filters, **opts.__dict__)
    for line in i.result:
        print line.encode(opts.output_encoding)
    return 0


if __name__ == '__main__':
    sys.exit(main())
