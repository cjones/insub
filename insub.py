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

"""Suite of text filters to annoy people on IRC"""

from __future__ import with_statement
import sys
from optparse import OptionParser
import os
from subprocess import Popen, PIPE, STDOUT
import shlex
import random

__version__ = '0.1'
__author__ = 'Chris Jones <cjones@gruntle.org>'
__all__ = ['Insub']

# defaults
SPOOKWORDS = 5

# list of spook words, stolen from emacs
SPOOK_PHRASES = (
        '$400 million in gold bullion',
        '[Hello to all my fans in domestic surveillance]', 'AK-47',
        'ammunition', 'arrangements', 'assassination', 'BATF', 'bomb', 'CIA',
        'class struggle', 'Clinton', 'Cocaine', 'colonel',
        'counter-intelligence', 'cracking', 'Croatian', 'cryptographic',
        'Delta Force', 'DES', 'domestic disruption', 'explosion', 'FBI', 'FSF',
        'fissionable', 'Ft. Bragg', 'Ft. Meade', 'genetic', 'Honduras',
        'jihad', 'Kennedy', 'KGB', 'Khaddafi', 'kibo', 'Legion of Doom',
        'Marxist', 'Mossad', 'munitions', 'Nazi', 'Noriega', 'North Korea',
        'NORAD', 'NSA', 'nuclear', 'Ortega', 'Panama', 'Peking', 'PLO',
        'plutonium', 'Qaddafi', 'quiche', 'radar', 'Rule Psix',
        'Saddam Hussein', 'SDI', 'SEAL Team 6', 'security', 'Semtex',
        'Serbian', 'smuggle', 'South Africa', 'Soviet ', 'spy', 'strategic',
        'supercomputer', 'terrorist', 'Treasury', 'Uzi', 'Waco, Texas',
        'World Trade Center', 'Liberals', 'Cheney', 'Eggs', 'Libya', 'Bush',
        'Kill the president', 'GOP', 'Republican', 'Shiite', 'Muslim',
        'Chemical Ali', 'Ashcroft', 'Terrorism', 'Al Qaeda', 'Al Jazeera',
        'Hamas', 'Israel', 'Palestine', 'Arabs', 'Arafat', 'Patriot Act',
        'Voter Fraud', 'Punch-cards', 'Diebold', 'conspiracy', 'Fallujah',
        'IndyMedia', 'Skull and Bones', 'Free Masons', 'Kerry', 'Grass Roots',
        '9-11', 'Rocket Propelled Grenades', 'Embedded Journalism',
        'Lockheed-Martin', 'war profiteering', 'Kill the President',
        'anarchy', 'echelon', 'nuclear', 'assassinate', 'Roswell', 'Waco',
        'World Trade Center', 'Soros', 'Whitewater', 'Lebed', 'HALO',
        'Spetznaz', 'Al Amn al-Askari', 'Glock 26', 'Steak Knife', 'Rewson',
        'SAFE', 'Waihopai', 'ASPIC', 'MI6', 'Information Security',
        'Information Warfare', 'Privacy', 'Information Terrorism',
        'Terrorism', 'Defensive Information', 'Defense Information Warfare',
        'Offensive Information', 'Offensive Information Warfare',
        'Ortega Waco', 'assasinate', 'National Information Infrastructure',
        'InfoSec', 'Computer Terrorism', 'DefCon V', 'Encryption', 'Espionage',
        'NSA', 'CIA', 'FBI', 'White House', 'Undercover', 'Compsec 97',
        'Europol', 'Military Intelligence', 'Verisign', 'Echelon',
        'Ufologico Nazionale', 'smuggle', 'Bletchley Park', 'Clandestine',
        'Counter Terrorism Security', 'Enemy of the State', '20755-6000',
        'Electronic Surveillance', 'Counterterrorism', 'eavesdropping',
        'nailbomb', 'Satellite imagery', 'subversives', 'World Domination',
        'wire transfer', 'jihad', 'fissionable', "Sayeret Mat'Kal",
        'HERF pipe-bomb', '2.3 Oz.  cocaine')


class Insub(object):

    """Suite of text filters to annoy people on IRC"""

    def __init__(self, **opts):
        self.__dict__.update(opts)

    def process(self):
        lines = self.data.splitlines()
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

    # filters that control the source text

    @filter()
    def ver(self, lines):
        """Display our version"""
        yield '%s %s' % (self.name, __version__)
        for line in lines:
            yield line

    @filter()
    def stdin(self, lines):
        """Add input from STDIN to data to process"""
        for line in sys.stdin:
            yield line
        for line in lines:
            yield line

    @filter()
    def execute(self, lines):
        """Execute args and add data to the output"""
        for line in lines:
            cmd = shlex.split(line)
            process = Popen(cmd, stdout=PIPE, stderr=STDOUT)
            for line in process.stdout:
                yield line.rstrip()

    @filter()
    def slurp(self, lines):
        """Read from files specified in args and add data to output"""
        for line in lines:
            with open(line, 'r') as fp:
                for line in fp:
                    yield line.rstrip()

    # dest metavar default action type nargs const choices callback help
    # store[_(const|true|false)] append[_const] count callback
    # string int long float complex choice

    @filter(spookwords=dict(metavar='<#>', default=SPOOKWORDS, type='int',
                            help='spook words to use (default: %default)'))
    def spook(self, lines):
        for line in lines:
            yield ' '.join(
                    [' '.join(random.sample(SPOOK_PHRASES, self.spookwords)),
                     line])

    # filters that change the text content

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

    # change the text appearance

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

    # change the text presentation

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

    # change the final visual appearance

    @filter()
    def rainbow(self, lines):
        return lines

    @filter()
    def tree(self, lines):
        return lines

    @filter()
    def blink(self, lines):
        return lines

    # ircii jukes

    @filter()
    def ircii_fake(self, lines):
        return lines

    @filter()
    def ircii_drop(self, lines):
        return lines

    # post-processing filters

    @filter()
    def prefix(self, lines):
        return lines

    @filter()
    def strip(self, lines):
        return lines

    # misc utility functions/properties

    @property
    def name(self):
        return os.path.basename(sys.argv[0])


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

    # put filters in their natural order
    opts.filters = []
    for func, options in Insub.filter.filters:
        if func in filters and func not in opts.filters:
            opts.filters.append(func)

    # any data provided on the command-line
    opts.data = ' '.join(args)

    # process data
    insub = Insub(**opts.__dict__)
    print insub.process()

    return 0


if __name__ == '__main__':
    sys.exit(main())
