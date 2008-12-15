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
from subprocess import Popen, PIPE, STDOUT
from collections import defaultdict
from optparse import OptionParser
import textwrap
import shlex
import random
import codecs
import math
import sys
import os
import re

__version__ = '0.1'
__author__ = 'Chris Jones <cjones@gruntle.org>'
__all__ = ['Insub']

# defaults
SPOOKWORDS = 5
ORDERED = False
SINE_HEIGHT = 5
SINE_FREQ = 0.3
SINE_BG = ' '
MATRIX_SIZE = 6
MATRIX_SPACING = 2
HUG_SIZE = 5
HUG_CHARS = '{', '}'

# default encodings to use
try:
    INPUT_ENCODING = codecs.lookup(sys.stdin.encoding).name
except:
    INPUT_ENCODING = sys.getdefaultencoding()

try:
    OUTPUT_ENCODING = codecs.lookup(sys.stdout.encoding).name
except:
    OUTPUT_ENCODING = sys.getdefaultencoding()

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
        'plutonium', 'Qaddafi', 'quiche', 'radar', 'Rule Psix', 'spy',
        'Saddam Hussein', 'SDI', 'SEAL Team 6', 'security', 'Semtex',
        'Serbian', 'smuggle', 'South Africa', 'Soviet Union', 'strategic',
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

# translation map for unicode upsidedown-ation
UNIFLIP = {8255: 8256, 8261: 8262, 33: 161, 34: 8222, 38: 8523, 39: 44, 40: 41,
           41: 40, 46: 729, 51: 400, 52: 5421, 54: 57, 55: 11362, 8756: 8757,
           59: 1563, 60: 62, 63: 191, 65: 8704, 67: 8579, 68: 9686, 69: 398,
           70: 8498, 71: 8513, 74: 383, 75: 8906, 76: 8514, 77: 87, 78: 7438,
           80: 1280, 81: 908, 82: 7450, 84: 8869, 85: 8745, 86: 7463,89: 8516,
           91: 93, 95: 8254, 97: 592, 98: 113, 99: 596, 100: 112, 101: 477,
           102: 607, 103: 387, 104: 613, 105: 305, 106: 638, 107: 670,
           108: 643, 109: 623, 110: 117, 114: 633, 116: 647, 118: 652,
           119: 653, 121: 654, 123: 125}

# ascii flip map if unicode is too much awesome
ASCIIFLIP = {47: 92, 92: 47,      # / <-> \
             118: 94, 94: 118,    # v <-> ^
             109: 119, 119: 109,  # m <-> w
             86: 94,              # V  -> ^
             77: 87, 87: 77,      # M <-> W
             112: 98, 98: 112,    # p <-> b
             45: 95, 95:45,       # - <-> _
             39: 44, 44: 39}      # , <-> '

# lexical translation rules for jive, ported from jive.c
JIVE_RULES = [
        ('file', 'stash'), ('send', "t'row"), ('program', 'honky code'),
        ('atlas', 'Isaac'), ('unix', 'slow mo-fo'), ('UNIX', 'dat slow mo-fo'),
        ('linux', 'dat leenucks mo-fo'), ('Linux', 'penguin unix'),
        ('LINUX', 'dat fast mo-fo'), (' takes ', " snatch'd "),
        (' take ', ' snatch '), ('Mexican', 'wet-back'),
        ('mexican', 'wet-back'), ('Italian', 'greaser'),
        ('italian', 'greaser'), ("don't", "duzn't"), ('Jive', 'Ebonics'),
        ('jive', 'JIBE'), ('[Ee]nglish', 'honky talk'), ('fool', 'honkyfool'),
        ('modem', 'doodad'), ('e the ', 'e da damn '),
        ('a the ', 'a da damn '), ('t the ', 't da damn '),
        ('d the ', 'd da damn '), (' man ', ' dude '), ('woman', 'mama'),
        ('women', 'honky chicks'), (' men ', ' dudes '), (' mens ', ' dudes '),
        ('girl', 'goat'), ('something', "sump'n"), (' lie ', ' honky jibe '),
        ('-o-', ' -on rebound- '), ('-oo-', " -check y'out latah-"),
        ('([a-b]\\.)', '\\1  Sheeeiit.'),
        ('([e-f]\\.)', '\\1  What it is, Mama!'),
        ('([i-j]\\.)', "\\1  Ya' know?"),
        ('([m-n]\\.)', "\\1  S coo', bro."),
        ('([q-r]\\.)', '\\1  Ah be baaad...'),
        ('([u-v]\\.)', '\\1  Man!'),
        ('([y-z]\\.)', '\\1  Slap mah fro!'),
        ('Sure', "Sho' nuff"), ('sure', "sho' nuff"), (' get', ' git'),
        ('will take', "gots'ta snatch"), ('will have', "gots'ta"),
        ('will ', "gots'ta "), ('got to', "gots'ta"),
        ('I am', "I's gots'ta be"), ("I'm", "I's"), ('am not', 'aint'),
        ('is not', 'aint'), ('are not', 'aint'), (' are your', " is yo'"),
        (' are you', ' you is'), (' hat ', ' fedora '), (' shoe', ' kicker'),
        ("haven't", 'aint'), ('have to', "gots'ta"), ('have', "gots'"),
        (' has', " gots'ta"), ('come over', 'mosey on down'),
        (' come ', ' mosey on down '), ('!', '.  Right On!  '),
        ('buy', 'steal'), (' car ', ' wheels '), ('drive', 'roll'),
        (' eat ', ' feed da bud '), (' black', ' brother'),
        (' negro', ' brother'), ('white ', 'honky'), (' nigger', ' gentleman'),
        ('nice', "supa' fine"), ('person', "sucka'"),
        (' thing', ' wahtahmellun'), ('home', 'plantation'),
        ('name', 'dojigger'), ('NAME', 'DOJIGGER'), ('syn', 'sin'),
        ('SYN', 'SIN'), (' path', ' alley'), ('computer', 'clunker'),
        ('or', "o'"), ('killed', 'wasted'), ('kill', 'put de smack down on'),
        ('kill you', "put de smack down on yo' ass"), ('heroin', 'smack'),
        ('marijuana', 'mary jane'), ('cocaine', 'cracker crack'),
        ('president', 'super-dude'), ('prime minister', 'super honcho'),
        ('injured', 'hosed'), ('government', "guv'ment"),
        ('knew', 'knowed'), ('because', "a'cuz"), ('Because', "A'cuz"),
        ('your', "yo'"), ('Your', "Yo'"), ('four', 'foe'), ('got', 'gots'),
        ("aren't", "ain't"), ('young', 'yung'), ('you', "ya'"),
        ('You', "You's"), ('first', 'fust'), ('police', 'honky pigs'),
        (' string', " chittlin'"), (' read', ' eyeball'),
        ('write', 'scribble'), ('th', 'd'), ('Th', 'D'), ('ing', "in'"),
        (' a ', ' some '), (' an ', ' some '), (' to ', " t'"),
        ('tion', 'shun'), ('TION', 'SHUN'), (' almost ', " mos' "),
        (' from', ' fum'), (' because ', " cuz' "), ("you're'", 'youse'),
        ("You're", 'Youse'), ('alright', "coo'"), ('okay', "coo'"),
        ('er ', "a' "), ('known', 'knode'), ('want', "wants'"),
        ('beat', "whup'"), ('exp', "'sp"), ('exs', "'s"), (' exc', " 's"),
        (' ex', " 'es"), ('like', 'likes'), ('did', 'dun did'),
        ('kind of', "kind'a"), ('dead', 'wasted'), ('good', 'baaaad'),
        ('open ', 'jimmey '), ('opened ', "jimmey'd "), (' very', ' real'),
        ('per', "puh'"), ('pera', "puh'"), ('oar', "o'"), (' can', ' kin'),
        ('just ', 'plum '), ('detroit', 'Mo-town'),
        ('western electric', "da' cave"), (' believe', " recon'"),
        ('[Ii]ndianapolis', 'Nap-town'), (' [Jj]ack', ' Buckwheat'),
        (' [Bb]ob ', " Liva' Lips "), (' [Pp]hil ', ' dat fine soul '),
        (' [Mm]ark ', ' Amos '), ('[Rr]obert', 'Leroy'),
        ('[Ss]andy', 'dat fine femahnaine ladee'), ('[Jj]ohn ', "Raz'tus "),
        (' [Pp]aul', " Fuh'rina"), ('[Rr]eagan', 'Kingfish'),
        ('[Dd]avid', 'Issac'), ('[Rr]onald', 'Rolo'),
        (' [Jj]im ', ' Bo-Jangles '), (' [Mm]ary', ' Snow Flake'),
        ('[Ll]arry', 'Remus'), ('[Jj]oe', "Massa'"), ('[Jj]oseph', "Massa'"),
        ('mohammed', "liva' lips"), ('pontiff', "wiz'"), ('pope', "wiz'"),
        ('pravda', 'dat commie rag'), ('broken', "bugger'd"),
        ('strange ', 'funky '), ('dance ', 'boogy '), (' house', ' crib'),
        ('ask', "ax'"), (' so ', " so's "), ('head', "'haid"),
        ('boss', 'main man'), ('wife', 'mama'), ('people', "sucka's"),
        ('money', "bre'd"), ('([a-z]:)', '\\1 dig dis:'),
        ('amateur', "begina'"), ('radio', "transista'"), (' of ', ' uh '),
        ('what', 'whut'), ('does', 'duz'), ('was', 'wuz'), (' were', ' wuz'),
        ('understand it', 'dig it'), ('understand', 'dig it'),
        (' my', " mah'"), (' [Ii] ', " ah' "), ('meta', "meta-fuckin'"),
        ('hair', 'fro'), ('talk', 'rap'), ('music', 'beat'),
        ('basket', 'hoop'), ('football', 'ball'), ('friend', 'homey'),
        ('school', 'farm'), ('want to', 'wanna'),
        ('wants to', "be hankerin' aftah"), ('well', 'sheeit'),
        ('Well', 'Sheeit'), ('big', 'big-ass'), ('bad', 'bad-ass'),
        ('small', 'little-ass'), ('sort of', 'radical'),
        (' is a ', ' be some '), (' is an ', ' be some '), (' is ', ' be '),
        ("It's", 'It be'), ("it's", 'it be'), ('water', 'booze'),
        ('book', "scribblin'"), ('magazine', 'issue of GQ'),
        ('paper', 'sheet'), (' up ', ' down '), ('down', 'waaay down'),
        ('break', 'boogie'), ('Hi', "'Sup, dude"), ('VAX', 'pink Cadillac')]

# pre-compile regex for jive rules
for i, rule in enumerate(JIVE_RULES):
    JIVE_RULES[i] = (re.compile(rule[0]), rule[1])

# leet speak character map
LEET_MAP = dict(a=['4', '/\\', '@', 'a', 'A'],
                b=['|o', 'b', 'B'],
                c=['C', 'c', '<'],
                d=['d', 'D', '|)'],
                e=['e', 'E', '3'],
                f=['f', 'F', '/='],
                g=['g', 'G', '6'],
                h=['h', 'H', '|-|'],
                i=['i', 'I', '|', '1'],
                j=['j', 'J'],
                k=['keke', 'x', 'X', 'k', 'K', '|<'],
                l=['l', 'L', '7', '|_'],
                m=['|V|', '|\\/|', 'm', 'M'],
                n=['n', 'N', '|\\|'],
                o=['0', 'o', 'O', '()', '[]', '<>'],
                p=['p', 'P', '9'],
                q=['q', 'Q'],
                r=['r', 'R'],
                s=['s', 'S', '5'],
                t=['t', 'T', '7'],
                u=['|_|', 'u', 'U', '\\/'],
                v=['v', 'V', '\\/'],
                w=['w', 'W', 'uu', 'UU', 'uU', 'Uu', '\\/\\/'],
                x=['x', 'X', '><'],
                y=['y', 'Y'],
                z=['z', 'Z', '5'])

# translation map for jigs
JIGS_MAP = {34: 104, 44: 46, 45: 61, 46: 47, 47: 110, 48: 45, 55: 56, 56: 57,
            57: 48, 59: 39, 61: 55, 91: 93, 92: 117, 93: 92, 104: 106,
            105: 111, 106: 107, 107: 108, 108: 59, 109: 46, 110: 109,
            111: 112, 112: 91, 117: 105, 121: 117}


class Insub(object):

    """Suite of text filters to annoy people on IRC"""

    def __init__(self, **opts):
        self.__dict__.update(opts)

        # normalize filters
        filters = []
        for filter in self.filters:
            if not isinstance(filter, basestring):
                filter = filter.__name__
            filters.append(getattr(self, filter).im_func)
        self.filters = filters

        # unless specified otherwise, put filters into their natural order
        if not self.ordered:
            filters = []
            for func, options in self.__class__.filter.filters:
                if func in self.filters and func not in filters:
                    filters.append(func)
            self.filters = filters

    @property
    def rendered(self):
        """Return rendered data"""
        lines = self.data.splitlines()
        for filter in self.filters:
            lines = filter(self, lines)
        return u'\n'.join(lines)

    class filter(object):

        """
        Decorator class to handle gluing filters to optparse and
        preserving natural filter order.
        """

        filters = []

        def __init__(self, **options):
            self.options = options

        def __call__(self, func):
            self.__class__.filters.append((func, self.options))
            return func

        @classmethod
        def setup(cls, parser):
            """Construct options for optparse"""
            filters = []

            def add_filter(option, key, val, parser, func):
                if val is not None:
                    setattr(parser.values, option.dest, val)
                filters.append(func)

            for func, options in cls.filters:
                filter_kwargs = dict(action='callback',
                                     callback=add_filter,
                                     callback_args=(func,),
                                     help=func.__doc__)
                extra_options = []
                for option, kwargs in options.iteritems():
                    if isinstance(kwargs, dict):
                        extra_options.append(('--' + option, kwargs))
                    else:
                        filter_kwargs[option] = kwargs
                parser.add_option('--' + func.__name__, **filter_kwargs)
                for opt, kwargs in extra_options:
                    parser.add_option(opt, **kwargs)

            return filters

    # filters that control the source text

    @filter()
    def ver(self, lines):
        """Display our version"""
        yield u'%s %s' % (self.name, __version__)
        for line in lines:
            yield line

    @filter()
    def stdin(self, lines):
        """Add input from STDIN to data to process"""
        for line in sys.stdin:
            yield line.rstrip().decode(self.input_encoding, 'replace')
        for line in lines:
            yield line

    @filter()
    def execute(self, lines):
        """Execute args and add data to the output"""
        for line in lines:
            line = line.encode(self.output_encoding, 'replace')
            cmd = shlex.split(line)
            process = Popen(cmd, stdout=PIPE, stderr=STDOUT)
            for line in process.stdout:
                yield line.rstrip().decode(self.input_encoding, 'replace')

    @filter()
    def slurp(self, lines):
        """Read from files and add data to output"""
        for line in lines:
            with open(line, 'r') as fp:
                for line in fp:
                    yield line.rstrip().decode(self.input_encoding, 'replace')

    @filter(spookwords=dict(metavar='<#>', default=SPOOKWORDS, type='int',
                            help='Spook words to use (default: %default)'))
    def spook(self, lines):
        """Get NSA's attention"""
        lines = list(lines)
        if not lines:
            yield self._get_spook()
        else:
            for line in lines:
                yield u' '.join([self._get_spook(), line])

    def _get_spook(self):
        return u' '.join(random.sample(SPOOK_PHRASES, self.spookwords))

    # filters that change the text content

    @filter()
    def jive(self, lines):
        """Make speech more funky"""
        for line in lines:
            for search, replace in JIVE_RULES:
                line = search.sub(replace, line)
            yield line

    @filter()
    def scramble(self, lines):
        """Scramble inner letters of a word"""
        for line in lines:
            new = []
            for word in line.split():
                if len(word) > 4:
                    word = list(word)
                    first = word.pop(0)
                    last = word.pop()
                    random.shuffle(word)
                    word = first + u''.join(word) + last
                new.append(word)
            yield ' '.join(new)

    @filter()
    def leet(self, lines):
        """Make text into leet-speak"""
        for line in lines:
            new = []
            for ch in line:
                if ch in LEET_MAP:
                    ch = random.choice(LEET_MAP[ch])
                new.append(ch)
            yield u''.join(new)

    @filter()
    def uniflip(self, lines):
        """Reverse text using unicode flippage"""
        for line in lines:
            yield line.translate(UNIFLIP)

    @filter()
    def asciiflip(self, lines):
        """Reverse text using ascii flippage"""
        for line in lines:
            yield line.translate(ASCIIFLIP)

    @filter()
    def mirror(self, lines):
        """Mirror image text"""
        lines = list(lines)
        size = len(max(lines, key=len))
        for line in lines:
            yield u' ' * (size - len(line)) + u''.join(reversed(line))

    @filter()
    def jigs(self, lines):
        """Shift right-hand homerow to the right"""
        for line in lines:
            yield line.translate(JIGS_MAP)

    # change the text appearance

    @filter(sine_height=dict(metavar='<int>', default=SINE_HEIGHT, type='int',
                             help='Height of wave (default: %default)'),
            sine_freq=dict(metavar='<float>', default=SINE_FREQ, type='float',
                           help='Wave frequency (default: %default)'),
            sine_bg=dict(metavar='<str>', default=SINE_BG,
                                 help='Sine background (default: %s)' %
                                 repr(SINE_BG)))
    def sine(self, lines):
        """Arrange text in a sine wave pattern"""
        out = defaultdict(unicode)
        line_num = 0
        for line in lines:
            width = len(line) * self.sine_freq
            plot = {}
            x = 0
            for ch in line:
                y = int(self.sine_height * math.sin(x)) + self.sine_height
                plot.setdefault('%.2f' % x, {})[y] = ch
                x += self.sine_freq
            for y in xrange(self.sine_height * 2 + 1):
                x = 0
                while x <= width:
                    xrep = '%.2f' % x
                    if xrep in plot and y in plot[xrep]:
                        out[line_num] += plot[xrep][y]
                    else:
                        out[line_num] += self.sine_bg
                    x += self.sine_freq
                line_num += 1
        bg_re = re.compile('^' + re.escape(self.sine_bg) + '+$')
        for i, line in sorted(out.iteritems()):
            if not bg_re.search(line):
                yield line

    @filter()
    def diagonal(self, lines):
        """Arrange text diagonally"""
        for line in lines:
            for i in xrange(len(line)):
                yield ' ' * i + line[i]

    @filter()
    def slope(self, lines):
        """Arrange text on a slope"""
        for line in lines:
            spacer = 0
            for word in line.split():
                yield ' ' * spacer + word
                spacer += len(word)

    @filter(matrix_size=dict(metavar='<int>', default=MATRIX_SIZE, type='int',
                             help='Matrix size (default: %default)'),
            matrix_spacing=dict(metavar='<int>', default=MATRIX_SPACING,
                                type='int',
                                help='Matrix spacing (default: %default)'))
    def matrix(self, lines):
        """Arrange text in a matrix"""
        data = ' '.join(lines)
        out = defaultdict(unicode)
        for i in xrange(0, len(data), self.matrix_size):
            chunk = data[i:i + self.matrix_size]
            for j in xrange(len(chunk)):
                out[j] += chunk[j] + ' ' * self.matrix_spacing
        for i, line in sorted(out.iteritems()):
            yield line

    @filter()
    def figlet(self, lines):
        # XXX complicated
        return lines

    @filter()
    def banner(self, lines):
        # XXX complicated
        return lines

    @filter(hug_size=dict(metavar='<int>', default=HUG_SIZE, type='int',
                          help='How many hugs (default: %default)'),
            hug_chars=dict(metavar='<left> <right>', default=HUG_CHARS, nargs=2,
                           help='Hugs chars (default: %s)' % repr(HUG_CHARS)))
    def hug(self, lines):
        """Add hugs around the text"""
        lines = list(lines)
        size = len(max(lines, key=len))
        left = self.hug_chars[0] * self.hug_size
        right = self.hug_chars[1] * self.hug_size
        for line in lines:
            yield '%s %s %s' % (left, line.center(size), right)

    @filter()
    def rotate(self, lines):
        return lines

    @filter(metavar='<width>', type='int')
    def wrap(self, lines):
        """Wrap text"""
        for line in textwrap.wrap(' '.join(lines), width=self.wrap):
            yield line

    @filter()
    def chalkboard(self, lines):
        return lines

    # change the text presentation

    @filter()
    def checker(self, lines):
        return lines

    @filter()
    def cow(self, lines):
        # XXX complicated
        return lines

    @filter()
    def flip(self, lines):
        """Flip over lines"""
        lines = list(lines)
        for line in reversed(lines):
            yield line

    @filter()
    def outline(self, lines):
        return lines

    # change the final visual appearance

    @filter()
    def rainbow(self, lines):
        # XXX complicated
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

    @filter(metavar='<text>', type='string')
    def prefix(self, lines):
        """Append text to each line"""
        for line in lines:
            yield self.prefix + line

    @filter()
    def strip(self, lines):
        return lines

    # misc utility functions/properties

    @property
    def name(self):
        """Name of the script"""
        return os.path.basename(sys.argv[0])


def main():
    # dest metavar default action type nargs const choices callback help
    # store[_(const|true|false)] append[_const] count callback
    # string int long float complex choice
    toggle = lambda x: ('store_%s' % (not x)).lower()
    parser = OptionParser(version=__version__)
    parser.add_option('-I', '--input-encoding', metavar='<encoding>',
                      default=INPUT_ENCODING,
                      help='Input encoding (default: %default)')
    parser.add_option('-O', '--output-encoding', metavar='<encoding>',
                      default=OUTPUT_ENCODING,
                      help='Output encoding (default: %default)')
    parser.add_option('-o', '--ordered', default=ORDERED,
                      action=toggle(ORDERED), help='Preserve order of filters')
    filters = Insub.filter.setup(parser)
    opts, args = parser.parse_args()

    # any data provided on the command-line
    data = ' '.join(arg.decode(opts.input_encoding, 'replace') for arg in args)

    # process data
    output = Insub(filters=filters, data=data, **opts.__dict__).rendered
    if output:
        print output.encode(opts.output_encoding, 'replace')
    else:
        parser.print_help()
    return 0


if __name__ == '__main__':
    sys.exit(main())
