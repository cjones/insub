########################################################################
# This script is an Irssi wrapper around insub.py, a Python            #
# implmentation of the original gay.pl.  When loaded it will write     #
# insub.py to your scripts dir if it does not exist or is out of date, #
# and act as a front-end for executing this.  You need Python 2.5+     #
# somewhere in your path for this to work, obviously.  See insub.py in #
# your scripts directory for more details.                             #
#                                                                      #
# A simple use case:                                                   #
#                                                                      #
# /insub "hugs" | figlet | cow | rainbow                               #
#                                                                      #
# For a complete list of filters and more complex expressions, type:   #
#                                                                      #
# /insub help                                                          #
########################################################################

use strict;
use POSIX;
use Irssi;

# perl :(
use constant False => 0;
use constant True => 1;

# regex to match version of insub.py
my $version_re = qr/__version__\s*=\s*['"]([0-9.]+)['"]/;

# regex to match a help request of some sort
my $help_re = qr/^\s*-*h(elp)?\s*$/i;

# external Irssi function
sub insub {
    my ($expr, $server, $dest) = @_;
    my ($output, $error);

    # no args passed, assume they need help
    $expr = '-h' if (!$expr);

    # run insub.py in an eval block in case it explodes so you don't get
    # rainbow shrapnel all over irc.
    eval {
        ($output, $error) = execute_insub($expr);
    };

    # stop is set on any error conditions to prevent output
    my $stop = False;

    # eval block explodinated
    if ($@) {
        Irssi::print("Died executing insub: $@");
        $stop = True;
    }

    # insub.py wrote to STDERR, which only happens on errors
    if (@$error) {
        foreach my $line (@$error) {
            Irssi::print("ERROR: $line");
        }
        $stop = True;
    }

    # you managed to somehow generate nothing, good job
    if (!@$output) {
        Irssi::print("No output to display");
        $stop = True;
    }

    # output is actually the usage, keep that to ourselves.
    if (@$output && $expr =~ $help_re) {
        foreach my $line (@$output) {
            Irssi::print($line)
        }
        $stop = True;
    }

    return if $stop;

    # emit rendered output
    foreach my $line (@$output) {
        $line = ' ' if $line eq '';  # need this to preserve empty lines
        $dest->command(sprintf('msg %s %s', $dest->{name}, $line));
    }
}


# execute real python script and return array ref to output and errors
sub execute_insub {
    my $expr = shift || return;

    # create pipes and then fork off
    pipe(RIN,  WIN);    # stdin
    pipe(ROUT, WOUT);   # stdout
    pipe(RERR, WERR);   # stderr

    my $pid = fork();
    die "Fork failed: $!\n" if (!defined $pid);

    # child handles go to pipe
    if ($pid == 0) {
        close(WIN)  && POSIX::dup2(fileno(RIN),  fileno(STDIN));
        close(ROUT) && POSIX::dup2(fileno(WOUT), fileno(STDOUT));
        close(RERR) && POSIX::dup2(fileno(WERR), fileno(STDERR));
    }

    # close unused handles, we don't want stuff LEAKING OUT OF OUR PIPE
    close(RIN);
    close(WOUT);
    close(WERR);

    # child executes insub.py with explicit encoding settings to prevent
    # faulty auto-detection from ruining christmas.
    if ($pid == 0) {
        my $cmd = Irssi::settings_get_str('insub_path');

        # some persistent data we want to pass to insub

        my @args = ('-s', Irssi::settings_get_str('insub_scheme'),
                    '-i', Irssi::settings_get_str('insub_encoding'),
                    '-o', Irssi::settings_get_str('insub_encoding'));

        my $cow_dir = Irssi::settings_get_str('insub_cow_dir');
        if ($cow_dir) {
            push(@args, '-c');
            push(@args, $cow_dir);
        }

        my $figlet_dir = Irssi::settings_get_str('insub_figlet_dir');
        if ($figlet_dir) {
            push(@args, '-f');
            push(@args, $figlet_dir);
        }

        # probably need a better way of doing this
        push(@args, '-h') if ($expr =~ $help_re);

        exec($cmd, @args);

        # this really shouldn't happen, maybe if $PATH is fubar
        Irssi::print('epic fork-exec failure, exiting');
        exit(1);
    }

    # write expression to insub.py's STDIN
    print WIN $expr;
    close(WIN);

    # collect any output.  this should probably use select() system call
    # to prevent deadlocks and other nastiness.
    my @output = split("\n", join('', <ROUT>)); close(ROUT);
    my @error  = split("\n", join('', <RERR>)); close(RERR);

    # need this to prevent zombies, although in theory this could cause
    # Irssi to hang, should probably be using WNOHANG with a timeout of
    # some sort to be safe.
    waitpid($pid, 0);

    return (\@output, \@error);
}


# this function is executed when insub is loaded. it creates the
# insub.py script if it doesn't exist, updates it if this version is
# newer, and provides irssi command bindings.
sub init_onload {
    my $data = shift;

    # where our scripts are located
    my $bin = sprintf("%s/scripts/insub.py", Irssi::get_irssi_dir());

    # see if we need to update the python script
    my $update = False;

    if (-e $bin) {
        open(IN, '<', $bin);
        my $old = join('', <IN>);
        close(IN);

        my ($old_version) = ($old =~ $version_re);
        my ($new_version) = ($data =~ $version_re);
        if ($new_version > $old_version) {
            Irssi::print("Updating Insub from $old_version to $new_version");
            $update = True;
        }
    } else {
        $update = True;
    }

    if ($update) {
        open(OUT, '>', $bin);
        print OUT $data;
        close(OUT);
        chmod 0755, $bin;
    }

    # if all went well, go ahead and bind irssi
    Irssi::command_bind('insub', \&insub);
    Irssi::settings_add_str('insub', 'insub_path', $bin);
    Irssi::settings_add_str('insub', 'insub_scheme', 'mirc');
    Irssi::settings_add_str('insub', 'insub_encoding', 'utf-8');
    Irssi::settings_add_str('insub', 'insub_cow_dir', '');
    Irssi::settings_add_str('insub', 'insub_figlet_dir', '');
    #Irssi::settings_add_int('insub', 'insub_paint_offset', 0);
}


# hard coded insub.py :P

my $data = <<'END_OF_INSUB_SCRIPT';
#!/usr/bin/env python
#
# Copyright (c) 2008-2009, Chris Jones
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
from collections import defaultdict
from optparse import OptionParser
from pty import fork as ptyfork
from select import select
import textwrap
import random
import shlex
import errno
import math
import sys
import os
import re

__version__ = '0.6'
__author__ = 'Chris Jones <cjones@gruntle.org>'
__all__ = ['Insub']

# defaults
INPUT_ENCODING = 'utf-8'
OUTPUT_ENCODING = 'utf-8'
SCHEME = 'ansi'
DEFAULTS = {'figlet_dir': None,
            'cow_dir': None,
            'execute_pty': False,
            'execute_timeout': None,
            'spook_words': 5,
            'sine_bg': ' ',
            'sine_freq': 0.3,
            'sine_height': 5,
            'matrix_size': 6,
            'matrix_spacing': 2,
            'figlet_font': 'standard',
            'figlet_direction': 'auto',
            'figlet_justify': 'auto',
            'figlet_reverse': False,
            'figlet_flip': False,
            'banner_width': 50,
            'banner_fg': '#',
            'banner_bg': ' ',
            'hug_size': 5,
            'hug_arms': '{}',
            'cow_file': 'default',
            'cow_style': 'say',
            'cow_eyes': 'oo',
            'cow_tongue': '  ',
            'outline_style': 'box',
            'prefix_string': '',
            'postfix_string': '',
            'paint_brush': 'rainbow',
            'paint_offset': 0,
            'paint_skew': 1,
            'rotate_cw': False,
            'wrap_width': 72,
            'dongs_freq': 3,
            'dongs_left': 'e==8',
            'dongs_right': '8==e',
            }

# try to find location of figlet and cowsay files

def find_share(name):
    """Find share directories of the provided name"""
    for prefix in ('/opt/local', '/usr/local', '/usr', '/'):
        for subdir in ('', 'share'):
            path = os.path.join(prefix, subdir, name)
            if os.path.isdir(path):
                return path

if not DEFAULTS['figlet_dir']:
    DEFAULTS['figlet_dir'] = find_share('figlet')

if not DEFAULTS['cow_dir']:
    DEFAULTS['cow_dir'] = find_share('cows')

# precompiled regex
newline_re = re.compile(r'\r?\n')
blank_re = re.compile(r'^\s*$')
lead_re = re.compile(r'^(\s+)')

# various presets for the rainbow filter
BRUSH_MAP = {'rainbow': 'rrRRyyYYGGggccCCBBbbmmMM',
             'rain2': 'rRyYGgcCBbmM',
             'rain3': 'RyYGcBM',
             'usa': 'RRWWBB',
             'blue': 'bB',
             'green': 'gG',
             'purple': 'mM',
             'grey': 'Dw',
             'yellow': 'yY',
             'red': 'Rr',
             'scale': 'WWwwCCDDCCww',
             'xmas': 'Rg',
             'canada': 'RRWW'}

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

# translation map for unibig
UNIBIG = dict((i, i + 65248) for i in xrange(33, 127))
UNIBIG[32] = 12288

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
        (' take ', ' snatch '),
        ("don't", "duzn't"), ('Jive', 'Ebonics'),
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
LEET_MAP = {'a': ['4', '/\\', '@', 'a', 'A'],
            'b': ['|o', 'b', 'B'],
            'c': ['C', 'c', '<'],
            'd': ['d', 'D', '|)'],
            'e': ['e', 'E', '3'],
            'f': ['f', 'F', '/='],
            'g': ['g', 'G', '6'],
            'h': ['h', 'H', '|-|'],
            'i': ['i', 'I', '|', '1'],
            'j': ['j', 'J'],
            'k': ['keke', 'x', 'X', 'k', 'K', '|<'],
            'l': ['l', 'L', '7', '|_'],
            'm': ['|V|', '|\\/|', 'm', 'M'],
            'n': ['n', 'N', '|\\|'],
            'o': ['0', 'o', 'O', '()', '[]', '<>'],
            'p': ['p', 'P', '9'],
            'q': ['q', 'Q'],
            'r': ['r', 'R'],
            's': ['s', 'S', '5'],
            't': ['t', 'T', '7'],
            'u': ['|_|', 'u', 'U', '\\/'],
            'v': ['v', 'V', '\\/'],
            'w': ['w', 'W', 'uu', 'UU', 'uU', 'Uu', '\\/\\/'],
            'x': ['x', 'X', '><'],
            'y': ['y', 'Y'],
            'z': ['z', 'Z', '5']}

# translation map for jigs
JIGS_MAP = {34: 104, 44: 46, 45: 61, 46: 47, 47: 110, 48: 45, 55: 56, 56: 57,
            57: 48, 59: 39, 61: 55, 91: 93, 92: 117, 93: 92, 104: 106,
            105: 111, 106: 107, 107: 108, 108: 59, 109: 46, 110: 109,
            111: 112, 112: 91, 117: 105, 121: 117}

# translation map for mirroring text
MIRROR_MAP = {47: 92, 92: 47, 60: 62, 62: 60, 40: 41, 41: 40, 123: 125,
              125: 123}

# chalkboard template
CHALKBOARD = """ _____________________________________________________________
| **********************************************    ^^^^^^^^\ |
| **********************************************    |       | |
| **********************************************    |_ __   | |
| **********************************************    (.(. )  | |
| ***************************************** _       (_      ) |
|                                           \\\\      /___/' /  |
|                                           _\\\\_      \    |  |
|                                          ((   )     /====|  |
|                                           \  <.__._-      \ |
|___________________________________________ <//___.         ||"""

# sort of self-explanatory
OUTLINE_STYLES = ('box', '3d', 'arrow')

# rules that define how the banner fonts are drawn
BANNER_RULES = {' ': [227],
                '!': [34, 6, 90, 19, 129, 32, 10, 74, 40, 129, 31, 12, 64, 53,
                      129, 30, 14, 54, 65, 129, 30, 14, 53, 67, 129, 30, 14,
                      54, 65, 129, 31, 12, 64, 53, 129, 32, 10, 74, 40, 129,
                      34, 6, 90, 19, 129, 194],
                '"': [99, 9, 129, 97, 14, 129, 96, 18, 129, 95, 22, 129, 95,
                      16, 117, 2, 129, 95, 14, 129, 96, 11, 129, 97, 9, 129,
                      99, 6, 129, 194],
                '#': [87, 4, 101, 4, 131, 82, 28, 131, 87, 4, 101, 4, 133, 82,
                      28, 131, 87, 4, 101, 4, 131, 193],
                '$': [39, 1, 84, 27, 129, 38, 3, 81, 32, 129, 37, 5, 79, 35,
                      129, 36, 5, 77, 38, 129, 35, 5, 76, 40, 129, 34, 5, 75,
                      21, 103, 14, 129, 33, 5, 74, 19, 107, 11, 129, 32, 5, 73,
                      17, 110, 9, 129, 32, 4, 73, 16, 112, 7, 129, 31, 4, 72,
                      15, 114, 6, 129, 31, 4, 72, 14, 115, 5, 129, 30, 4, 71,
                      15, 116, 5, 129, 27, 97, 131, 30, 4, 69, 14, 117, 4, 129,
                      30, 4, 68, 15, 117, 4, 132, 30, 4, 68, 14, 117, 4, 129,
                      27, 97, 131, 30, 5, 65, 15, 116, 5, 129, 31, 4, 65, 14,
                      116, 4, 129, 31, 6, 64, 15, 116, 4, 129, 32, 7, 62, 16,
                      115, 4, 129, 32, 9, 61, 17, 114, 5, 129, 33, 11, 58, 19,
                      113, 5, 129, 34, 14, 55, 21, 112, 5, 129, 35, 40, 111, 5,
                      129, 36, 38, 110, 5, 129, 37, 35, 109, 5, 129, 38, 32,
                      110, 3, 129, 40, 27, 111, 1, 129, 193],
                '%': [30, 4, 103, 9, 129, 30, 7, 100, 15, 129, 30, 10, 99, 17,
                      129, 33, 10, 97, 6, 112, 6, 129, 36, 10, 96, 5, 114, 5,
                      129, 39, 10, 96, 4, 115, 4, 129, 42, 10, 95, 4, 116, 4,
                      129, 45, 10, 95, 3, 117, 3, 129, 48, 10, 95, 3, 117, 3,
                      129, 51, 10, 95, 4, 116, 4, 129, 54, 10, 96, 4, 115, 4,
                      129, 57, 10, 96, 5, 114, 5, 129, 60, 10, 97, 6, 112, 6,
                      129, 63, 10, 99, 17, 129, 66, 10, 100, 15, 129, 69, 10,
                      103, 9, 129, 39, 9, 72, 10, 129, 36, 15, 75, 10, 129, 35,
                      17, 78, 10, 129, 33, 6, 48, 6, 81, 10, 129, 32, 5, 50, 5,
                      84, 10, 129, 32, 4, 51, 4, 87, 10, 129, 31, 4, 52, 4, 90,
                      10, 129, 31, 3, 53, 3, 93, 10, 129, 31, 3, 53, 3, 96, 10,
                      129, 31, 4, 52, 4, 99, 10, 129, 32, 4, 51, 4, 102, 10,
                      129, 32, 5, 50, 5, 105, 10, 129, 33, 6, 48, 6, 108, 10,
                      129, 35, 17, 111, 10, 129, 36, 15, 114, 7, 129, 40, 9,
                      118, 4, 129, 193],
                '&': [48, 18, 129, 43, 28, 129, 41, 32, 129, 39, 36, 129, 37,
                      40, 129, 35, 44, 129, 34, 46, 129, 33, 13, 68, 13, 129,
                      32, 9, 73, 9, 129, 32, 7, 75, 7, 129, 31, 6, 77, 6, 129,
                      31, 5, 78, 5, 129, 30, 5, 79, 5, 129, 20, 74, 132, 30, 4,
                      80, 4, 129, 31, 3, 79, 4, 129, 31, 4, 79, 4, 129, 32, 3,
                      78, 4, 129, 32, 4, 76, 6, 129, 33, 4, 74, 7, 129, 34, 4,
                      72, 8, 129, 35, 5, 72, 7, 129, 37, 5, 73, 4, 129, 39, 4,
                      74, 1, 129, 129, 193],
                "'": [111, 6, 129, 109, 10, 129, 108, 12, 129, 107, 14, 129,
                      97, 2, 105, 16, 129, 99, 22, 129, 102, 18, 129, 105, 14,
                      129, 108, 9, 129, 194],
                '(': [63, 25, 129, 57, 37, 129, 52, 47, 129, 48, 55, 129, 44,
                      63, 129, 41, 69, 129, 38, 75, 129, 36, 79, 129, 34, 83,
                      129, 33, 28, 90, 28, 129, 32, 23, 96, 23, 129, 32, 17,
                      102, 17, 129, 31, 13, 107, 13, 129, 30, 9, 112, 9, 129,
                      30, 5, 116, 5, 129, 30, 1, 120, 1, 129, 194],
                ')': [30, 1, 120, 1, 129, 30, 5, 116, 5, 129, 30, 9, 112, 9,
                      129, 31, 13, 107, 13, 129, 32, 17, 102, 17, 129, 32, 23,
                      96, 23, 129, 33, 28, 90, 28, 129, 34, 83, 129, 36, 79,
                      129, 38, 75, 129, 41, 69, 129, 44, 63, 129, 48, 55, 129,
                      52, 47, 129, 57, 37, 129, 63, 25, 129, 194],
                '*': [80, 4, 130, 80, 4, 129, 68, 2, 80, 4, 94, 2, 129, 66, 6,
                      80, 4, 92, 6, 129, 67, 7, 80, 4, 90, 7, 129, 69, 7, 80,
                      4, 88, 7, 129, 71, 6, 80, 4, 87, 6, 129, 72, 20, 129, 74,
                      16, 129, 76, 12, 129, 62, 40, 131, 76, 12, 129, 74, 16,
                      129, 72, 20, 129, 71, 6, 80, 4, 87, 6, 129, 69, 7, 80, 4,
                      88, 7, 129, 67, 7, 80, 4, 90, 7, 129, 66, 6, 80, 4, 92,
                      6, 129, 68, 2, 80, 4, 94, 2, 129, 80, 4, 130, 193],
                '+': [60, 4, 139, 41, 42, 131, 60, 4, 139, 193],
                ',': [34, 6, 129, 32, 10, 129, 31, 12, 129, 30, 14, 129, 20,
                      2, 28, 16, 129, 22, 22, 129, 24, 19, 129, 27, 15, 129,
                      31, 9, 129, 194],
                '-': [60, 4, 152, 193],
                '.': [34, 6, 129, 32, 10, 129, 31, 12, 129, 30, 14, 131, 31,
                      12, 129, 32, 10, 129, 34, 6, 129, 194],
                '/': [30, 4, 129, 30, 7, 129, 30, 10, 129, 33, 10, 129, 36,
                      10, 129, 39, 10, 129, 42, 10, 129, 45, 10, 129, 48, 10,
                      129, 51, 10, 129, 54, 10, 129, 57, 10, 129, 60, 10, 129,
                      63, 10, 129, 66, 10, 129, 69, 10, 129, 72, 10, 129, 75,
                      10, 129, 78, 10, 129, 81, 10, 129, 84, 10, 129, 87, 10,
                      129, 90, 10, 129, 93, 10, 129, 96, 10, 129, 99, 10, 129,
                      102, 10, 129, 105, 10, 129, 108, 10, 129, 111, 10, 129,
                      114, 7, 129, 117, 4, 129, 193],
                '0': [60, 31, 129, 53, 45, 129, 49, 53, 129, 46, 59, 129, 43,
                      65, 129, 41, 69, 129, 39, 73, 129, 37, 77, 129, 36, 79,
                      129, 35, 15, 101, 15, 129, 34, 11, 106, 11, 129, 33, 9,
                      109, 9, 129, 32, 7, 112, 7, 129, 31, 6, 114, 6, 129, 31,
                      5, 115, 5, 129, 30, 5, 116, 5, 129, 30, 4, 117, 4, 132,
                      30, 5, 116, 5, 129, 31, 5, 115, 5, 129, 31, 6, 114, 6,
                      129, 32, 7, 112, 7, 129, 33, 9, 109, 9, 129, 34, 11, 106,
                      11, 129, 35, 15, 101, 15, 129, 36, 79, 129, 37, 77, 129,
                      39, 73, 129, 41, 69, 129, 43, 65, 129, 46, 59, 129, 49,
                      53, 129, 53, 45, 129, 60, 31, 129, 193],
                '1': [30, 4, 129, 30, 4, 100, 1, 129, 30, 4, 100, 3, 129, 30,
                      4, 100, 5, 129, 30, 76, 129, 30, 78, 129, 30, 80, 129,
                      30, 82, 129, 30, 83, 129, 30, 85, 129, 30, 87, 129, 30,
                      89, 129, 30, 91, 129, 30, 4, 132, 193],
                '2': [30, 3, 129, 30, 7, 129, 30, 10, 112, 1, 129, 30, 13,
                      112, 2, 129, 30, 16, 112, 3, 129, 30, 18, 111, 5, 129,
                      30, 21, 111, 6, 129, 30, 23, 112, 6, 129, 30, 14, 47, 8,
                      113, 6, 129, 30, 14, 49, 8, 114, 5, 129, 30, 14, 51, 8,
                      115, 5, 129, 30, 14, 53, 8, 116, 4, 129, 30, 14, 55, 8,
                      116, 5, 129, 30, 14, 56, 9, 117, 4, 129, 30, 14, 57, 9,
                      117, 4, 129, 30, 14, 58, 10, 117, 4, 129, 30, 14, 59, 10,
                      117, 4, 129, 30, 14, 60, 11, 117, 4, 129, 30, 14, 61, 11,
                      116, 5, 129, 30, 14, 62, 11, 116, 5, 129, 30, 14, 63, 12,
                      115, 6, 129, 30, 14, 64, 13, 114, 7, 129, 30, 14, 65, 13,
                      113, 8, 129, 30, 14, 65, 15, 111, 9, 129, 30, 14, 66, 16,
                      109, 11, 129, 30, 14, 67, 17, 107, 12, 129, 30, 14, 68,
                      20, 103, 16, 129, 30, 14, 69, 49, 129, 30, 14, 70, 47,
                      129, 30, 14, 71, 45, 129, 30, 14, 73, 42, 129, 30, 15,
                      75, 38, 129, 33, 12, 77, 34, 129, 36, 10, 79, 30, 129,
                      40, 6, 82, 23, 129, 44, 3, 86, 15, 129, 47, 1, 129, 193],
                '3': [129, 38, 3, 129, 37, 5, 111, 1, 129, 36, 7, 111, 2, 129,
                      35, 9, 110, 5, 129, 34, 8, 110, 6, 129, 33, 7, 109, 8,
                      129, 32, 7, 110, 8, 129, 32, 6, 112, 7, 129, 31, 6, 113,
                      6, 129, 31, 5, 114, 6, 129, 30, 5, 115, 5, 129, 30, 5,
                      116, 4, 129, 30, 4, 117, 4, 131, 30, 4, 117, 4, 129, 30,
                      4, 79, 2, 117, 4, 129, 30, 5, 78, 4, 117, 4, 129, 30, 5,
                      77, 6, 116, 5, 129, 30, 6, 76, 8, 115, 6, 129, 30, 7, 75,
                      11, 114, 6, 129, 30, 8, 73, 15, 112, 8, 129, 31, 9, 71,
                      19, 110, 9, 129, 31, 11, 68, 26, 107, 12, 129, 32, 13,
                      65, 14, 82, 36, 129, 32, 16, 61, 17, 83, 34, 129, 33, 44,
                      84, 32, 129, 34, 42, 85, 30, 129, 35, 40, 87, 27, 129,
                      36, 38, 89, 23, 129, 38, 34, 92, 17, 129, 40, 30, 95, 11,
                      129, 42, 26, 129, 45, 20, 129, 49, 11, 129, 193],
                '4': [49, 1, 129, 49, 4, 129, 49, 6, 129, 49, 8, 129, 49, 10,
                      129, 49, 12, 129, 49, 14, 129, 49, 17, 129, 49, 19, 129,
                      49, 21, 129, 49, 23, 129, 49, 14, 65, 9, 129, 49, 14, 67,
                      9, 129, 49, 14, 69, 9, 129, 49, 14, 71, 10, 129, 49, 14,
                      74, 9, 129, 49, 14, 76, 9, 129, 49, 14, 78, 9, 129, 49,
                      14, 80, 9, 129, 49, 14, 82, 9, 129, 49, 14, 84, 9, 129,
                      30, 4, 49, 14, 86, 10, 129, 30, 4, 49, 14, 89, 9, 129,
                      30, 4, 49, 14, 91, 9, 129, 30, 4, 49, 14, 93, 9, 129, 30,
                      74, 129, 30, 76, 129, 30, 78, 129, 30, 81, 129, 30, 83,
                      129, 30, 85, 129, 30, 87, 129, 30, 89, 129, 30, 91, 129,
                      30, 4, 49, 14, 132, 193],
                '5': [37, 1, 129, 36, 3, 77, 3, 129, 35, 5, 78, 11, 129, 34,
                      7, 78, 21, 129, 33, 7, 79, 29, 129, 32, 7, 79, 38, 129,
                      32, 6, 80, 4, 92, 29, 129, 31, 6, 80, 5, 102, 19, 129,
                      31, 5, 80, 6, 107, 14, 129, 31, 4, 81, 5, 107, 14, 129,
                      30, 5, 81, 6, 107, 14, 129, 30, 4, 81, 6, 107, 14, 130,
                      30, 4, 81, 7, 107, 14, 129, 30, 4, 80, 8, 107, 14, 130,
                      30, 5, 80, 8, 107, 14, 129, 30, 5, 79, 9, 107, 14, 129,
                      31, 5, 79, 9, 107, 14, 129, 31, 6, 78, 10, 107, 14, 129,
                      32, 6, 76, 11, 107, 14, 129, 32, 8, 74, 13, 107, 14, 129,
                      33, 10, 71, 16, 107, 14, 129, 33, 15, 67, 19, 107, 14,
                      129, 34, 51, 107, 14, 129, 35, 49, 107, 14, 129, 36, 47,
                      107, 14, 129, 37, 45, 107, 14, 129, 39, 41, 107, 14, 129,
                      41, 37, 107, 14, 129, 44, 32, 107, 14, 129, 47, 25, 111,
                      10, 129, 51, 16, 115, 6, 129, 119, 2, 129, 193],
                '6': [56, 39, 129, 51, 49, 129, 47, 57, 129, 44, 63, 129, 42,
                      67, 129, 40, 71, 129, 38, 75, 129, 37, 77, 129, 35, 81,
                      129, 34, 16, 74, 5, 101, 16, 129, 33, 11, 76, 5, 107, 11,
                      129, 32, 9, 77, 5, 110, 9, 129, 32, 7, 79, 4, 112, 7,
                      129, 31, 6, 80, 4, 114, 6, 129, 31, 5, 81, 4, 115, 5,
                      129, 30, 5, 82, 4, 116, 5, 129, 30, 4, 82, 4, 116, 5,
                      129, 30, 4, 82, 5, 117, 4, 131, 30, 5, 82, 5, 117, 4,
                      129, 31, 5, 81, 6, 117, 4, 129, 31, 6, 80, 7, 117, 4,
                      129, 32, 7, 79, 8, 117, 4, 129, 32, 9, 77, 9, 116, 5,
                      129, 33, 11, 75, 11, 116, 4, 129, 34, 16, 69, 16, 115, 5,
                      129, 35, 49, 114, 5, 129, 37, 46, 113, 5, 129, 38, 44,
                      112, 6, 129, 40, 41, 112, 5, 129, 42, 37, 113, 3, 129,
                      44, 33, 114, 1, 129, 47, 27, 129, 51, 17, 129, 193],
                '7': [103, 2, 129, 103, 6, 129, 104, 9, 129, 105, 12, 129,
                      106, 15, 129, 107, 14, 135, 30, 10, 107, 14, 129, 30, 17,
                      107, 14, 129, 30, 25, 107, 14, 129, 30, 31, 107, 14, 129,
                      30, 37, 107, 14, 129, 30, 42, 107, 14, 129, 30, 46, 107,
                      14, 129, 30, 50, 107, 14, 129, 30, 54, 107, 14, 129, 30,
                      58, 107, 14, 129, 59, 32, 107, 14, 129, 64, 30, 107, 14,
                      129, 74, 23, 107, 14, 129, 81, 18, 107, 14, 129, 86, 16,
                      107, 14, 129, 91, 14, 107, 14, 129, 96, 25, 129, 100, 21,
                      129, 104, 17, 129, 107, 14, 129, 111, 10, 129, 114, 7,
                      129, 117, 4, 129, 120, 1, 129, 193],
                '8': [48, 13, 129, 44, 21, 129, 42, 26, 129, 40, 30, 92, 12,
                      129, 38, 34, 88, 20, 129, 36, 37, 86, 25, 129, 35, 39,
                      84, 29, 129, 34, 13, 63, 12, 82, 33, 129, 33, 11, 67, 9,
                      80, 36, 129, 32, 9, 70, 7, 79, 38, 129, 31, 8, 72, 46,
                      129, 30, 7, 74, 22, 108, 11, 129, 30, 6, 75, 19, 111, 9,
                      129, 30, 5, 75, 17, 113, 7, 129, 30, 5, 74, 16, 114, 6,
                      129, 30, 4, 73, 16, 115, 6, 129, 30, 4, 72, 16, 116, 5,
                      129, 30, 4, 72, 15, 117, 4, 129, 30, 4, 71, 16, 117, 4,
                      129, 30, 5, 70, 16, 117, 4, 129, 30, 5, 70, 15, 117, 4,
                      129, 30, 6, 69, 15, 116, 5, 129, 30, 7, 68, 17, 115, 5,
                      129, 30, 9, 67, 19, 114, 6, 129, 30, 10, 65, 22, 113, 6,
                      129, 31, 12, 63, 27, 110, 9, 129, 32, 14, 60, 21, 84, 9,
                      106, 12, 129, 33, 47, 85, 32, 129, 34, 45, 86, 30, 129,
                      35, 43, 88, 26, 129, 36, 40, 90, 22, 129, 38, 36, 93, 17,
                      129, 40, 32, 96, 10, 129, 42, 28, 129, 44, 23, 129, 48,
                      15, 129, 193],
                '9': [83, 17, 129, 77, 27, 129, 36, 1, 74, 33, 129, 35, 3, 72,
                      37, 129, 34, 5, 70, 41, 129, 33, 6, 69, 44, 129, 33, 5,
                      68, 46, 129, 32, 5, 67, 49, 129, 31, 5, 66, 17, 101, 16,
                      129, 31, 5, 66, 11, 108, 10, 129, 30, 4, 65, 9, 110, 9,
                      129, 30, 4, 64, 8, 112, 7, 129, 30, 4, 64, 7, 114, 6,
                      129, 30, 4, 64, 6, 115, 5, 129, 30, 4, 64, 5, 116, 5,
                      129, 30, 4, 64, 5, 117, 4, 131, 30, 4, 65, 4, 117, 4,
                      129, 30, 5, 65, 4, 116, 5, 129, 31, 5, 66, 4, 115, 5,
                      129, 31, 6, 67, 4, 114, 6, 129, 32, 7, 68, 4, 112, 7,
                      129, 32, 9, 69, 5, 110, 9, 129, 33, 11, 70, 5, 107, 11,
                      129, 34, 16, 72, 5, 101, 16, 129, 35, 81, 129, 37, 77,
                      129, 38, 75, 129, 40, 71, 129, 42, 67, 129, 44, 63, 129,
                      47, 57, 129, 51, 49, 129, 56, 39, 129, 193],
                ':': [34, 6, 74, 6, 129, 32, 10, 72, 10, 129, 31, 12, 71, 12,
                      129, 30, 14, 70, 14, 131, 31, 12, 71, 12, 129, 32, 10,
                      72, 10, 129, 34, 6, 74, 6, 129, 194],
                ';': [34, 6, 74, 6, 129, 32, 10, 72, 10, 129, 31, 12, 71, 12,
                      129, 30, 14, 70, 14, 129, 20, 2, 28, 16, 70, 14, 129, 22,
                      22, 70, 14, 129, 24, 19, 71, 12, 129, 27, 15, 72, 10,
                      129, 31, 9, 74, 6, 129, 194],
                '<': [129, 65, 21, 129, 64, 23, 129, 63, 25, 129, 62, 27, 129,
                      61, 29, 129, 60, 31, 129, 59, 16, 76, 16, 129, 58, 16,
                      77, 16, 129, 57, 16, 78, 16, 129, 56, 16, 78, 16, 129,
                      55, 16, 79, 16, 129, 54, 16, 80, 16, 129, 53, 16, 81, 16,
                      129, 52, 16, 82, 16, 129, 51, 16, 83, 16, 129, 50, 16,
                      84, 16, 129, 49, 16, 85, 16, 129, 48, 16, 86, 16, 129,
                      47, 16, 87, 16, 129, 46, 16, 88, 16, 129, 45, 16, 89, 16,
                      129, 46, 14, 90, 14, 129, 193],
                '=': [53, 4, 63, 4, 152, 193],
                #'=': [53, 4, 88, 6, 152, 193],  # shaft!
                '>': [129, 46, 14, 90, 14, 129, 45, 16, 89, 16, 129, 46, 16,
                      88, 16, 129, 47, 16, 87, 16, 129, 48, 16, 86, 16, 129,
                      49, 16, 85, 16, 129, 50, 16, 84, 16, 129, 51, 16, 83, 16,
                      129, 52, 16, 82, 16, 129, 53, 16, 81, 16, 129, 54, 16,
                      80, 16, 129, 55, 16, 79, 16, 129, 56, 16, 78, 16, 129,
                      57, 16, 78, 16, 129, 58, 16, 77, 16, 129, 59, 16, 76, 16,
                      129, 60, 31, 129, 61, 29, 129, 62, 27, 129, 63, 25, 129,
                      64, 23, 129, 65, 21, 129, 193],
                '?': [99, 7, 129, 97, 13, 129, 96, 16, 129, 96, 18, 129, 96,
                      19, 129, 97, 19, 129, 99, 6, 110, 7, 129, 112, 6, 129,
                      114, 5, 129, 34, 6, 57, 5, 115, 4, 129, 32, 10, 54, 12,
                      116, 4, 129, 31, 12, 53, 16, 117, 3, 129, 30, 14, 52, 20,
                      117, 4, 129, 30, 14, 52, 23, 117, 4, 129, 30, 14, 52, 25,
                      117, 4, 129, 31, 12, 52, 27, 117, 4, 129, 32, 10, 53, 10,
                      70, 11, 116, 5, 129, 34, 6, 55, 5, 73, 10, 115, 6, 129,
                      74, 11, 114, 7, 129, 75, 12, 112, 9, 129, 76, 13, 110,
                      10, 129, 77, 16, 106, 14, 129, 78, 41, 129, 80, 38, 129,
                      81, 36, 129, 82, 34, 129, 84, 30, 129, 86, 26, 129, 88,
                      22, 129, 92, 14, 129, 194],
                '@': [55, 15, 129, 50, 25, 129, 47, 32, 129, 45, 13, 70, 12,
                      129, 43, 9, 76, 10, 129, 42, 6, 79, 8, 129, 41, 5, 81, 7,
                      129, 40, 4, 84, 6, 129, 39, 4, 59, 12, 85, 6, 129, 38, 4,
                      55, 19, 87, 5, 129, 37, 4, 53, 23, 88, 4, 129, 36, 4, 51,
                      8, 71, 6, 89, 4, 129, 36, 4, 51, 6, 73, 4, 89, 4, 129,
                      36, 4, 50, 6, 74, 4, 90, 3, 129, 35, 4, 50, 5, 75, 3, 90,
                      4, 129, 35, 4, 50, 4, 75, 4, 90, 4, 131, 35, 4, 50, 5,
                      75, 4, 90, 4, 129, 36, 4, 51, 5, 75, 4, 90, 4, 129, 36,
                      4, 51, 6, 75, 4, 90, 4, 129, 36, 4, 53, 26, 90, 4, 129,
                      37, 4, 54, 25, 90, 4, 129, 37, 4, 52, 27, 90, 3, 129, 38,
                      4, 52, 4, 89, 4, 129, 39, 4, 51, 4, 88, 4, 129, 40, 4,
                      50, 4, 87, 5, 129, 41, 4, 50, 4, 86, 5, 129, 42, 4, 50,
                      4, 85, 5, 129, 43, 3, 50, 4, 83, 6, 129, 44, 2, 51, 5,
                      80, 7, 129, 46, 1, 52, 6, 76, 9, 129, 54, 28, 129, 56,
                      23, 129, 60, 16, 129, 193],
                'A': [30, 4, 132, 30, 5, 129, 30, 8, 129, 30, 12, 129, 30, 16,
                      129, 30, 4, 37, 12, 129, 30, 4, 41, 12, 129, 30, 4, 44,
                      13, 129, 30, 4, 48, 13, 129, 52, 13, 129, 56, 12, 129,
                      58, 14, 129, 58, 4, 64, 12, 129, 58, 4, 68, 12, 129, 58,
                      4, 72, 12, 129, 58, 4, 75, 13, 129, 58, 4, 79, 13, 129,
                      58, 4, 83, 13, 129, 58, 4, 87, 13, 129, 58, 4, 91, 12,
                      129, 58, 4, 95, 12, 129, 58, 4, 96, 15, 129, 58, 4, 93,
                      22, 129, 58, 4, 89, 30, 129, 58, 4, 85, 36, 129, 58, 4,
                      81, 38, 129, 58, 4, 77, 38, 129, 58, 4, 73, 38, 129, 58,
                      4, 70, 37, 129, 58, 4, 66, 37, 129, 58, 41, 129, 58, 37,
                      129, 54, 38, 129, 30, 4, 50, 38, 129, 30, 4, 46, 38, 129,
                      30, 4, 42, 38, 129, 30, 4, 38, 39, 129, 30, 43, 129, 30,
                      39, 129, 30, 35, 129, 30, 31, 129, 30, 27, 129, 30, 24,
                      129, 30, 20, 129, 30, 16, 129, 30, 12, 129, 30, 8, 129,
                      30, 5, 129, 30, 4, 132, 193],
                'B': [30, 4, 117, 4, 132, 30, 91, 137, 30, 4, 80, 4, 117, 4,
                      138, 30, 4, 80, 5, 116, 5, 129, 30, 5, 79, 6, 116, 5,
                      130, 30, 6, 78, 8, 115, 6, 129, 31, 6, 77, 9, 115, 6,
                      129, 31, 7, 76, 11, 114, 6, 129, 31, 8, 75, 14, 112, 8,
                      129, 32, 8, 74, 16, 111, 9, 129, 32, 9, 73, 19, 109, 10,
                      129, 33, 10, 71, 24, 106, 13, 129, 33, 13, 68, 12, 83,
                      35, 129, 34, 16, 64, 15, 84, 33, 129, 35, 43, 85, 31,
                      129, 36, 41, 86, 29, 129, 37, 39, 88, 25, 129, 38, 37,
                      90, 21, 129, 40, 33, 93, 15, 129, 42, 29, 96, 9, 129, 45,
                      24, 129, 49, 16, 129, 193],
                'C': [63, 25, 129, 57, 37, 129, 53, 45, 129, 50, 51, 129, 47,
                      57, 129, 45, 61, 129, 43, 65, 129, 41, 69, 129, 39, 73,
                      129, 38, 25, 92, 21, 129, 36, 21, 97, 18, 129, 35, 18,
                      102, 14, 129, 34, 16, 106, 11, 129, 33, 14, 108, 10, 129,
                      32, 12, 111, 8, 129, 32, 10, 113, 6, 129, 31, 10, 114, 6,
                      129, 31, 8, 115, 5, 129, 30, 8, 116, 5, 129, 30, 7, 116,
                      5, 129, 30, 6, 117, 4, 130, 30, 5, 117, 4, 131, 31, 4,
                      116, 5, 129, 32, 4, 116, 4, 129, 32, 5, 115, 5, 129, 33,
                      4, 114, 5, 129, 34, 4, 112, 6, 129, 35, 4, 110, 7, 129,
                      37, 4, 107, 9, 129, 39, 4, 103, 12, 129, 41, 4, 103, 18,
                      129, 43, 4, 103, 18, 129, 45, 5, 103, 18, 129, 48, 5,
                      103, 18, 129, 51, 1, 129, 193],
                'D': [30, 4, 117, 4, 132, 30, 91, 137, 30, 4, 117, 4, 135, 30,
                      5, 116, 5, 130, 30, 6, 115, 6, 130, 31, 6, 114, 6, 129,
                      31, 7, 113, 7, 129, 32, 7, 112, 7, 129, 32, 8, 111, 8,
                      129, 33, 9, 109, 9, 129, 33, 12, 106, 12, 129, 34, 13,
                      104, 13, 129, 35, 15, 101, 15, 129, 36, 19, 96, 19, 129,
                      37, 24, 90, 24, 129, 39, 73, 129, 40, 71, 129, 42, 67,
                      129, 44, 63, 129, 46, 59, 129, 49, 53, 129, 52, 47, 129,
                      56, 39, 129, 61, 29, 129, 193],
                'E': [30, 4, 117, 4, 132, 30, 91, 137, 30, 4, 80, 4, 117, 4,
                      140, 30, 4, 79, 6, 117, 4, 129, 30, 4, 77, 10, 117, 4,
                      129, 30, 4, 73, 18, 117, 4, 132, 30, 4, 117, 4, 130, 30,
                      5, 116, 5, 130, 30, 7, 114, 7, 129, 30, 8, 113, 8, 129,
                      30, 11, 110, 11, 129, 30, 18, 103, 18, 132, 193],
                'F': [30, 4, 117, 4, 132, 30, 91, 137, 30, 4, 80, 4, 117, 4,
                      132, 80, 4, 117, 4, 136, 79, 6, 117, 4, 129, 77, 10, 117,
                      4, 129, 73, 18, 117, 4, 132, 117, 4, 130, 116, 5, 130,
                      114, 7, 129, 113, 8, 129, 110, 11, 129, 103, 18, 132,
                      193],
                'G': [63, 25, 129, 57, 37, 129, 53, 45, 129, 50, 51, 129, 47,
                      57, 129, 45, 61, 129, 43, 65, 129, 41, 69, 129, 39, 73,
                      129, 38, 25, 92, 21, 129, 36, 21, 97, 18, 129, 35, 18,
                      102, 14, 129, 34, 16, 106, 11, 129, 33, 14, 108, 10, 129,
                      32, 12, 111, 8, 129, 32, 10, 113, 6, 129, 31, 10, 114, 6,
                      129, 31, 8, 115, 5, 129, 30, 8, 116, 5, 129, 30, 7, 116,
                      5, 129, 30, 6, 117, 4, 130, 30, 5, 117, 4, 131, 30, 5,
                      75, 4, 116, 5, 129, 31, 5, 75, 4, 116, 4, 129, 31, 6, 75,
                      4, 115, 5, 129, 32, 7, 75, 4, 114, 5, 129, 32, 9, 75, 4,
                      112, 6, 129, 33, 11, 75, 4, 110, 7, 129, 34, 15, 75, 4,
                      107, 9, 129, 35, 44, 103, 12, 129, 36, 43, 103, 18, 129,
                      38, 41, 103, 18, 129, 39, 40, 103, 18, 129, 41, 38, 103,
                      18, 129, 44, 35, 129, 48, 31, 129, 52, 27, 129, 61, 18,
                      129, 193],
                'H': [30, 4, 117, 4, 132, 30, 91, 137, 30, 4, 80, 4, 117, 4,
                      132, 80, 4, 140, 30, 4, 80, 4, 117, 4, 132, 30, 91, 137,
                      30, 4, 117, 4, 132, 193],
                'I': [30, 4, 117, 4, 132, 30, 91, 137, 30, 4, 117, 4, 132,
                      193],
                'J': [44, 7, 129, 40, 13, 129, 37, 17, 129, 35, 20, 129, 34,
                      22, 129, 33, 23, 129, 32, 24, 129, 32, 23, 129, 31, 6,
                      41, 13, 129, 31, 5, 42, 11, 129, 30, 5, 44, 7, 129, 30,
                      4, 132, 30, 5, 130, 31, 5, 129, 31, 6, 117, 4, 129, 31,
                      8, 117, 4, 129, 32, 9, 117, 4, 129, 33, 11, 117, 4, 129,
                      34, 87, 129, 35, 86, 129, 36, 85, 129, 37, 84, 129, 38,
                      83, 129, 40, 81, 129, 42, 79, 129, 45, 76, 129, 50, 71,
                      129, 117, 4, 132, 193],
                'K': [30, 4, 117, 4, 132, 30, 91, 137, 30, 4, 76, 8, 117, 4,
                      129, 30, 4, 73, 13, 117, 4, 129, 30, 4, 70, 18, 117, 4,
                      129, 30, 4, 67, 23, 117, 4, 129, 65, 26, 129, 62, 31,
                      129, 59, 35, 129, 56, 29, 89, 7, 129, 53, 29, 91, 7, 129,
                      50, 29, 93, 7, 129, 47, 29, 95, 6, 129, 30, 4, 45, 29,
                      96, 7, 129, 30, 4, 42, 29, 98, 7, 129, 30, 4, 39, 30,
                      100, 6, 129, 30, 4, 36, 30, 101, 7, 129, 30, 33, 103, 7,
                      117, 4, 129, 30, 30, 105, 6, 117, 4, 129, 30, 27, 106, 7,
                      117, 4, 129, 30, 25, 108, 7, 117, 4, 129, 30, 22, 110,
                      11, 129, 30, 19, 111, 10, 129, 30, 16, 113, 8, 129, 30,
                      13, 115, 6, 129, 30, 11, 116, 5, 129, 30, 8, 117, 4, 129,
                      30, 5, 117, 4, 129, 30, 4, 117, 4, 130, 30, 4, 130, 193],
                'L': [30, 4, 117, 4, 132, 30, 91, 137, 30, 4, 117, 4, 132, 30,
                      4, 144, 30, 5, 130, 30, 7, 129, 30, 8, 129, 30, 11, 129,
                      30, 18, 132, 193],
                'M': [30, 4, 117, 4, 132, 30, 91, 132, 30, 4, 103, 18, 129,
                      30, 4, 97, 24, 129, 30, 4, 92, 29, 129, 30, 4, 87, 34,
                      129, 81, 40, 129, 76, 45, 129, 70, 49, 129, 65, 49, 129,
                      60, 49, 129, 55, 49, 129, 50, 48, 129, 44, 49, 129, 39,
                      48, 129, 33, 49, 129, 30, 47, 129, 34, 37, 129, 40, 26,
                      129, 46, 19, 129, 52, 19, 129, 58, 19, 129, 64, 19, 129,
                      70, 19, 129, 76, 19, 129, 82, 19, 129, 30, 4, 88, 18,
                      129, 30, 4, 94, 18, 129, 30, 4, 100, 18, 129, 30, 4, 106,
                      15, 129, 30, 91, 137, 30, 4, 117, 4, 132, 193],
                'N': [30, 4, 117, 4, 132, 30, 91, 132, 30, 4, 107, 14, 129,
                      30, 4, 104, 17, 129, 30, 4, 101, 20, 129, 30, 4, 99, 22,
                      129, 96, 25, 129, 93, 28, 129, 91, 28, 129, 88, 29, 129,
                      85, 29, 129, 82, 29, 129, 79, 29, 129, 76, 29, 129, 74,
                      29, 129, 71, 29, 129, 68, 29, 129, 65, 29, 129, 62, 29,
                      129, 60, 29, 129, 57, 29, 129, 54, 29, 129, 51, 29, 129,
                      49, 28, 129, 46, 29, 129, 43, 29, 129, 40, 29, 117, 4,
                      129, 37, 29, 117, 4, 129, 35, 29, 117, 4, 129, 32, 29,
                      117, 4, 129, 30, 91, 132, 117, 4, 132, 193],
                'O': [63, 25, 129, 57, 37, 129, 53, 45, 129, 50, 51, 129, 47,
                      57, 129, 45, 61, 129, 43, 65, 129, 41, 69, 129, 39, 73,
                      129, 38, 21, 92, 21, 129, 36, 18, 97, 18, 129, 35, 14,
                      102, 14, 129, 34, 11, 106, 11, 129, 33, 10, 108, 10, 129,
                      32, 8, 111, 8, 129, 32, 6, 113, 6, 129, 31, 6, 114, 6,
                      129, 31, 5, 115, 5, 129, 30, 5, 116, 5, 130, 30, 4, 117,
                      4, 132, 30, 5, 116, 5, 130, 31, 5, 115, 5, 129, 31, 6,
                      114, 6, 129, 32, 6, 113, 6, 129, 32, 8, 111, 8, 129, 33,
                      10, 108, 10, 129, 34, 11, 106, 11, 129, 35, 14, 102, 14,
                      129, 36, 18, 97, 18, 129, 38, 21, 92, 21, 129, 39, 73,
                      129, 41, 69, 129, 43, 65, 129, 45, 61, 129, 47, 57, 129,
                      50, 51, 129, 53, 45, 129, 57, 37, 129, 63, 25, 129, 193],
                'P': [30, 4, 117, 4, 132, 30, 91, 137, 30, 4, 80, 4, 117, 4,
                      132, 80, 4, 117, 4, 134, 80, 5, 116, 5, 131, 80, 6, 115,
                      6, 130, 81, 6, 114, 6, 129, 81, 8, 112, 8, 129, 81, 9,
                      111, 9, 129, 82, 10, 109, 10, 129, 82, 13, 106, 13, 129,
                      83, 35, 129, 84, 33, 129, 85, 31, 129, 86, 29, 129, 88,
                      25, 129, 90, 21, 129, 93, 15, 129, 96, 9, 129, 193],
                'Q': [63, 25, 129, 57, 37, 129, 53, 45, 129, 50, 51, 129, 47,
                      57, 129, 45, 61, 129, 43, 65, 129, 41, 69, 129, 39, 73,
                      129, 38, 21, 92, 21, 129, 36, 18, 97, 18, 129, 35, 14,
                      102, 14, 129, 34, 11, 106, 11, 129, 33, 10, 108, 10, 129,
                      32, 8, 111, 8, 129, 32, 6, 113, 6, 129, 31, 6, 114, 6,
                      129, 31, 5, 115, 5, 129, 30, 5, 116, 5, 130, 30, 4, 39,
                      2, 117, 4, 129, 30, 4, 40, 4, 117, 4, 129, 30, 4, 41, 5,
                      117, 4, 129, 30, 4, 41, 6, 117, 4, 129, 30, 5, 40, 8,
                      116, 5, 129, 30, 5, 39, 10, 116, 5, 129, 31, 5, 38, 11,
                      115, 5, 129, 31, 18, 114, 6, 129, 32, 17, 113, 6, 129,
                      32, 16, 111, 8, 129, 33, 15, 108, 10, 129, 33, 14, 106,
                      11, 129, 32, 17, 102, 14, 129, 31, 23, 97, 18, 129, 31,
                      28, 92, 21, 129, 30, 82, 129, 30, 80, 129, 30, 11, 43,
                      65, 129, 30, 10, 45, 61, 129, 31, 8, 47, 57, 129, 32, 6,
                      50, 51, 129, 33, 5, 53, 45, 129, 35, 4, 57, 37, 129, 38,
                      2, 63, 25, 129, 193],
                'R': [30, 4, 117, 4, 132, 30, 91, 137, 30, 4, 76, 8, 117, 4,
                      129, 30, 4, 73, 11, 117, 4, 129, 30, 4, 70, 14, 117, 4,
                      129, 30, 4, 67, 17, 117, 4, 129, 65, 19, 117, 4, 129, 62,
                      22, 117, 4, 129, 59, 25, 117, 4, 129, 56, 28, 117, 4,
                      129, 53, 31, 117, 4, 129, 50, 34, 117, 4, 129, 47, 29,
                      80, 5, 116, 5, 129, 30, 4, 45, 29, 80, 5, 116, 5, 129,
                      30, 4, 42, 29, 80, 5, 116, 5, 129, 30, 4, 39, 30, 80, 6,
                      115, 6, 129, 30, 4, 36, 30, 80, 6, 115, 6, 129, 30, 33,
                      81, 6, 114, 6, 129, 30, 30, 81, 8, 112, 8, 129, 30, 27,
                      81, 9, 111, 9, 129, 30, 25, 82, 10, 109, 10, 129, 30, 22,
                      82, 13, 106, 13, 129, 30, 19, 83, 35, 129, 30, 16, 84,
                      33, 129, 30, 13, 85, 31, 129, 30, 11, 86, 29, 129, 30, 8,
                      88, 25, 129, 30, 5, 90, 21, 129, 30, 4, 93, 15, 129, 30,
                      4, 96, 9, 129, 30, 4, 130, 193],
                'S': [30, 18, 130, 30, 18, 89, 15, 129, 30, 18, 85, 23, 129,
                      34, 11, 83, 27, 129, 34, 9, 81, 31, 129, 33, 8, 79, 35,
                      129, 33, 6, 78, 16, 106, 9, 129, 32, 6, 77, 15, 109, 7,
                      129, 32, 5, 76, 14, 111, 6, 129, 31, 5, 75, 14, 113, 5,
                      129, 31, 4, 74, 15, 114, 5, 129, 31, 4, 74, 14, 115, 4,
                      129, 30, 4, 73, 15, 116, 4, 129, 30, 4, 73, 14, 116, 4,
                      129, 30, 4, 73, 14, 117, 4, 129, 30, 4, 72, 15, 117, 4,
                      130, 30, 4, 71, 15, 117, 4, 130, 30, 4, 70, 15, 117, 4,
                      129, 30, 5, 70, 15, 117, 4, 129, 30, 5, 69, 15, 116, 5,
                      129, 30, 6, 68, 16, 115, 5, 129, 31, 6, 67, 16, 114, 6,
                      129, 31, 7, 66, 17, 113, 6, 129, 32, 7, 64, 18, 111, 8,
                      129, 32, 8, 62, 19, 109, 9, 129, 33, 9, 60, 20, 107, 10,
                      129, 34, 11, 57, 22, 103, 13, 129, 35, 43, 103, 18, 129,
                      36, 41, 103, 18, 129, 38, 38, 103, 18, 129, 39, 35, 103,
                      18, 129, 41, 31, 129, 43, 27, 129, 46, 22, 129, 49, 14,
                      129, 193],
                'T': [103, 18, 132, 110, 11, 129, 113, 8, 129, 114, 7, 129,
                      116, 5, 130, 117, 4, 132, 30, 4, 117, 4, 132, 30, 91,
                      137, 30, 4, 117, 4, 132, 117, 4, 132, 116, 5, 130, 114,
                      7, 129, 113, 8, 129, 110, 11, 129, 103, 18, 132, 193],
                'U': [117, 4, 132, 56, 65, 129, 50, 71, 129, 46, 75, 129, 44,
                      77, 129, 42, 79, 129, 40, 81, 129, 38, 83, 129, 36, 85,
                      129, 35, 86, 129, 34, 20, 117, 4, 129, 33, 17, 117, 4,
                      129, 32, 15, 117, 4, 129, 32, 13, 117, 4, 129, 31, 12,
                      129, 31, 10, 129, 31, 9, 129, 30, 9, 129, 30, 8, 130, 30,
                      7, 132, 31, 6, 130, 31, 7, 129, 32, 6, 129, 32, 7, 129,
                      33, 7, 129, 34, 7, 129, 35, 8, 129, 36, 9, 117, 4, 129,
                      38, 9, 117, 4, 129, 40, 10, 117, 4, 129, 42, 12, 117, 4,
                      129, 44, 77, 129, 46, 75, 129, 50, 71, 129, 56, 43, 100,
                      21, 129, 117, 4, 132, 193],
                'V': [117, 4, 132, 115, 6, 129, 110, 11, 129, 105, 16, 129,
                      101, 20, 129, 96, 25, 129, 92, 29, 129, 87, 34, 129, 83,
                      38, 129, 78, 43, 129, 74, 47, 129, 70, 42, 117, 4, 129,
                      65, 42, 117, 4, 129, 60, 43, 117, 4, 129, 56, 42, 129,
                      51, 42, 129, 46, 43, 129, 42, 43, 129, 37, 44, 129, 33,
                      43, 129, 30, 42, 129, 33, 34, 129, 38, 25, 129, 42, 16,
                      129, 47, 15, 129, 52, 15, 129, 57, 15, 129, 61, 16, 129,
                      66, 16, 129, 71, 16, 129, 76, 16, 129, 80, 16, 129, 85,
                      16, 117, 4, 129, 90, 16, 117, 4, 129, 95, 16, 117, 4,
                      129, 100, 21, 129, 105, 16, 129, 110, 11, 129, 114, 7,
                      129, 117, 4, 132, 193],
                'W': [117, 4, 132, 115, 6, 129, 110, 11, 129, 105, 16, 129,
                      101, 20, 129, 96, 25, 129, 92, 29, 129, 87, 34, 129, 83,
                      38, 129, 78, 43, 129, 74, 47, 129, 70, 42, 117, 4, 129,
                      65, 42, 117, 4, 129, 60, 43, 117, 4, 129, 56, 42, 129,
                      51, 42, 129, 46, 43, 129, 42, 43, 129, 37, 44, 129, 33,
                      43, 129, 30, 42, 129, 33, 34, 129, 38, 25, 129, 42, 16,
                      129, 47, 15, 129, 52, 15, 129, 57, 15, 129, 61, 16, 129,
                      65, 17, 129, 60, 27, 129, 56, 36, 129, 51, 42, 129, 46,
                      43, 129, 42, 43, 129, 37, 44, 129, 33, 43, 129, 30, 42,
                      129, 33, 34, 129, 38, 25, 129, 42, 16, 129, 47, 15, 129,
                      52, 15, 129, 57, 15, 129, 61, 16, 129, 66, 16, 129, 71,
                      16, 129, 76, 16, 129, 80, 16, 129, 85, 16, 117, 4, 129,
                      90, 16, 117, 4, 129, 95, 16, 117, 4, 129, 100, 21, 129,
                      105, 16, 129, 110, 11, 129, 114, 7, 129, 117, 4, 132,
                      193],
                'X': [30, 4, 117, 4, 132, 30, 4, 115, 6, 129, 30, 4, 112, 9,
                      129, 30, 6, 109, 12, 129, 30, 9, 106, 15, 129, 30, 11,
                      103, 18, 129, 30, 14, 100, 21, 129, 30, 4, 38, 9, 98, 23,
                      129, 30, 4, 40, 10, 95, 26, 129, 30, 4, 43, 9, 92, 29,
                      129, 46, 9, 89, 32, 129, 49, 8, 86, 28, 117, 4, 129, 51,
                      9, 83, 28, 117, 4, 129, 54, 9, 80, 28, 117, 4, 129, 57,
                      8, 77, 28, 117, 4, 129, 59, 9, 74, 28, 129, 62, 37, 129,
                      64, 33, 129, 66, 28, 129, 63, 28, 129, 60, 28, 129, 57,
                      28, 129, 54, 33, 129, 51, 39, 129, 48, 29, 83, 9, 129,
                      30, 4, 45, 29, 86, 9, 129, 30, 4, 42, 29, 89, 9, 129, 30,
                      4, 39, 29, 92, 8, 129, 30, 4, 36, 29, 94, 9, 129, 30, 32,
                      97, 9, 129, 30, 29, 100, 8, 117, 4, 129, 30, 26, 103, 8,
                      117, 4, 129, 30, 23, 105, 9, 117, 4, 129, 30, 20, 108,
                      13, 129, 30, 18, 111, 10, 129, 30, 15, 113, 8, 129, 30,
                      12, 116, 5, 129, 30, 9, 117, 4, 129, 30, 6, 117, 4, 129,
                      30, 4, 117, 4, 132, 193],
                'Y': [117, 4, 132, 114, 7, 129, 111, 10, 129, 108, 13, 129,
                      105, 16, 129, 102, 19, 129, 100, 21, 129, 96, 25, 129,
                      93, 28, 129, 90, 31, 129, 87, 34, 129, 84, 30, 117, 4,
                      129, 30, 4, 81, 30, 117, 4, 129, 30, 4, 78, 30, 117, 4,
                      129, 30, 4, 75, 30, 117, 4, 129, 30, 4, 72, 30, 129, 30,
                      69, 129, 30, 66, 129, 30, 63, 129, 30, 60, 129, 30, 57,
                      129, 30, 54, 129, 30, 51, 129, 30, 48, 129, 30, 51, 129,
                      30, 4, 73, 12, 129, 30, 4, 76, 12, 129, 30, 4, 80, 12,
                      129, 30, 4, 83, 12, 129, 87, 12, 129, 90, 12, 117, 4,
                      129, 94, 11, 117, 4, 129, 97, 12, 117, 4, 129, 101, 12,
                      117, 4, 129, 104, 17, 129, 108, 13, 129, 111, 10, 129,
                      115, 6, 129, 117, 4, 134, 193],
                'Z': [30, 1, 103, 18, 129, 30, 4, 103, 18, 129, 30, 7, 103,
                      18, 129, 30, 9, 103, 18, 129, 30, 12, 110, 11, 129, 30,
                      15, 113, 8, 129, 30, 18, 114, 7, 129, 30, 21, 116, 5,
                      129, 30, 24, 116, 5, 129, 30, 27, 117, 4, 129, 30, 30,
                      117, 4, 129, 30, 33, 117, 4, 129, 30, 4, 37, 28, 117, 4,
                      129, 30, 4, 40, 28, 117, 4, 129, 30, 4, 42, 29, 117, 4,
                      129, 30, 4, 45, 29, 117, 4, 129, 30, 4, 48, 29, 117, 4,
                      129, 30, 4, 51, 29, 117, 4, 129, 30, 4, 54, 29, 117, 4,
                      129, 30, 4, 57, 29, 117, 4, 129, 30, 4, 59, 30, 117, 4,
                      129, 30, 4, 62, 30, 117, 4, 129, 30, 4, 65, 30, 117, 4,
                      129, 30, 4, 68, 30, 117, 4, 129, 30, 4, 71, 30, 117, 4,
                      129, 30, 4, 74, 30, 117, 4, 129, 30, 4, 77, 30, 117, 4,
                      129, 30, 4, 80, 30, 117, 4, 129, 30, 4, 83, 30, 117, 4,
                      129, 30, 4, 86, 35, 129, 30, 4, 89, 32, 129, 30, 4, 91,
                      30, 129, 30, 4, 94, 27, 129, 30, 5, 97, 24, 129, 30, 5,
                      100, 21, 129, 30, 7, 103, 18, 129, 30, 8, 106, 15, 129,
                      30, 11, 109, 12, 129, 30, 18, 112, 9, 129, 30, 18, 115,
                      6, 129, 30, 18, 117, 4, 129, 30, 18, 120, 1, 129, 193],
                '`': [99, 9, 129, 97, 14, 129, 96, 18, 129, 95, 22, 129, 95,
                      16, 117, 2, 129, 95, 14, 129, 96, 11, 129, 97, 9, 129,
                      99, 6, 129, 194],
                'a': [42, 8, 129, 38, 16, 129, 36, 20, 129, 34, 24, 71, 5,
                      129, 33, 26, 69, 10, 129, 32, 28, 68, 13, 129, 31, 30,
                      68, 14, 129, 31, 9, 52, 9, 68, 15, 129, 30, 8, 54, 8, 69,
                      14, 129, 30, 7, 55, 7, 71, 4, 78, 6, 129, 30, 6, 56, 6,
                      79, 5, 129, 30, 6, 56, 6, 80, 4, 130, 31, 5, 56, 5, 80,
                      4, 129, 31, 5, 56, 5, 79, 5, 129, 32, 5, 55, 5, 78, 6,
                      129, 33, 5, 54, 5, 77, 7, 129, 34, 6, 52, 6, 74, 9, 129,
                      35, 48, 129, 33, 49, 129, 32, 49, 129, 31, 49, 129, 30,
                      49, 129, 30, 47, 129, 30, 45, 129, 30, 41, 129, 30, 6,
                      129, 30, 4, 129, 30, 3, 129, 30, 2, 129, 193],
                'b': [30, 4, 117, 4, 130, 31, 90, 136, 37, 5, 72, 5, 129, 35,
                      5, 74, 5, 129, 33, 5, 76, 5, 129, 32, 5, 77, 5, 129, 31,
                      5, 78, 5, 129, 31, 4, 79, 4, 129, 30, 5, 79, 5, 131, 30,
                      6, 78, 6, 129, 30, 7, 77, 7, 129, 31, 8, 75, 8, 129, 31,
                      11, 72, 11, 129, 32, 15, 67, 15, 129, 33, 48, 129, 34,
                      46, 129, 35, 44, 129, 37, 40, 129, 39, 36, 129, 42, 30,
                      129, 46, 22, 129, 193],
                'c': [48, 18, 129, 43, 28, 129, 41, 32, 129, 39, 36, 129, 37,
                      40, 129, 35, 44, 129, 34, 46, 129, 33, 13, 68, 13, 129,
                      32, 9, 73, 9, 129, 32, 7, 75, 7, 129, 31, 6, 77, 6, 129,
                      31, 5, 78, 5, 129, 30, 5, 79, 5, 129, 30, 4, 80, 4, 133,
                      31, 3, 79, 4, 129, 31, 4, 79, 4, 129, 32, 3, 78, 4, 129,
                      32, 4, 76, 6, 129, 33, 4, 74, 7, 129, 34, 4, 72, 8, 129,
                      35, 5, 72, 7, 129, 37, 5, 73, 4, 129, 39, 4, 74, 1, 129,
                      129, 193],
                'd': [46, 22, 129, 42, 30, 129, 39, 36, 129, 37, 40, 129, 35,
                      44, 129, 34, 46, 129, 33, 48, 129, 32, 15, 67, 15, 129,
                      31, 11, 72, 11, 129, 31, 8, 75, 8, 129, 30, 7, 77, 7,
                      129, 30, 6, 78, 6, 129, 30, 5, 79, 5, 131, 31, 4, 79, 4,
                      129, 31, 5, 78, 5, 129, 32, 5, 77, 5, 129, 33, 5, 76, 5,
                      129, 35, 5, 74, 5, 117, 4, 129, 37, 5, 72, 5, 117, 4,
                      129, 30, 91, 136, 30, 4, 130, 193],
                'e': [48, 18, 129, 43, 28, 129, 41, 32, 129, 39, 36, 129, 37,
                      40, 129, 35, 44, 129, 34, 46, 129, 33, 13, 55, 4, 68, 13,
                      129, 32, 9, 55, 4, 73, 9, 129, 32, 7, 55, 4, 75, 7, 129,
                      31, 6, 55, 4, 77, 6, 129, 31, 5, 55, 4, 78, 5, 129, 30,
                      5, 55, 4, 79, 5, 129, 30, 4, 55, 4, 80, 4, 132, 30, 4,
                      55, 4, 79, 5, 129, 31, 3, 55, 4, 78, 5, 129, 31, 4, 55,
                      4, 77, 6, 129, 32, 3, 55, 4, 75, 7, 129, 32, 4, 55, 4,
                      73, 9, 129, 33, 4, 55, 4, 68, 13, 129, 34, 4, 55, 25,
                      129, 35, 5, 55, 24, 129, 37, 5, 55, 22, 129, 39, 4, 55,
                      20, 129, 55, 18, 129, 55, 16, 129, 55, 11, 129, 193],
                'f': [80, 4, 129, 30, 4, 80, 4, 130, 30, 78, 129, 30, 82, 129,
                      30, 85, 129, 30, 87, 129, 30, 88, 129, 30, 89, 129, 30,
                      90, 130, 30, 4, 80, 4, 115, 6, 129, 30, 4, 80, 4, 117, 4,
                      129, 80, 4, 105, 6, 117, 4, 129, 80, 4, 103, 10, 116, 5,
                      129, 80, 4, 102, 19, 129, 80, 4, 101, 19, 129, 101, 19,
                      129, 101, 18, 129, 102, 16, 129, 103, 12, 129, 105, 6,
                      129, 193],
                'g': [12, 10, 59, 11, 129, 9, 16, 55, 19, 129, 7, 20, 53, 23,
                      129, 6, 7, 23, 5, 32, 6, 51, 27, 129, 4, 7, 25, 16, 50,
                      29, 129, 3, 6, 27, 16, 49, 31, 129, 2, 6, 28, 16, 48, 33,
                      129, 1, 6, 27, 18, 47, 35, 129, 1, 6, 27, 31, 71, 12,
                      129, 1, 5, 26, 15, 44, 10, 75, 8, 129, 1, 5, 25, 14, 45,
                      7, 77, 7, 129, 1, 5, 25, 13, 45, 5, 79, 5, 129, 1, 5, 24,
                      14, 45, 4, 80, 4, 129, 1, 5, 24, 13, 45, 4, 80, 4, 129,
                      1, 5, 23, 14, 45, 4, 80, 4, 129, 1, 5, 23, 13, 45, 4, 80,
                      4, 129, 1, 6, 22, 13, 45, 5, 79, 5, 129, 1, 6, 21, 14,
                      45, 7, 77, 7, 129, 1, 7, 21, 13, 46, 8, 75, 8, 129, 1, 8,
                      20, 13, 46, 12, 71, 12, 129, 1, 10, 18, 15, 47, 35, 129,
                      2, 30, 48, 33, 129, 3, 29, 49, 32, 129, 4, 27, 50, 31,
                      129, 5, 25, 51, 27, 80, 2, 86, 4, 129, 7, 21, 53, 23, 80,
                      3, 85, 6, 129, 9, 17, 55, 19, 80, 12, 129, 12, 12, 59,
                      11, 81, 11, 129, 82, 10, 129, 84, 7, 129, 86, 4, 129,
                      193],
                'h': [30, 4, 117, 4, 130, 30, 91, 136, 30, 4, 72, 5, 129, 30,
                      4, 74, 5, 129, 75, 5, 129, 76, 5, 129, 76, 6, 129, 77, 6,
                      130, 77, 7, 130, 76, 8, 129, 30, 4, 75, 9, 129, 30, 4,
                      72, 12, 129, 30, 54, 129, 30, 53, 130, 30, 52, 129, 30,
                      51, 129, 30, 49, 129, 30, 46, 129, 30, 42, 129, 30, 4,
                      130, 193],
                'i': [30, 4, 80, 4, 129, 30, 4, 80, 4, 100, 6, 129, 30, 54,
                      98, 10, 129, 30, 54, 97, 12, 129, 30, 54, 96, 14, 131,
                      30, 54, 97, 12, 129, 30, 54, 98, 10, 129, 30, 54, 100, 6,
                      129, 30, 4, 130, 193],
                'j': [7, 6, 129, 4, 11, 129, 3, 13, 129, 2, 14, 129, 1, 15,
                      130, 1, 3, 6, 9, 129, 1, 3, 7, 6, 129, 1, 3, 130, 1, 4,
                      129, 1, 5, 80, 4, 129, 1, 7, 80, 4, 100, 6, 129, 2, 82,
                      98, 10, 129, 3, 81, 97, 12, 129, 4, 80, 96, 14, 129, 5,
                      79, 96, 14, 129, 7, 77, 96, 14, 129, 10, 74, 97, 12, 129,
                      14, 70, 98, 10, 129, 19, 65, 100, 6, 129, 193],
                'k': [30, 4, 117, 4, 130, 30, 91, 136, 30, 4, 57, 9, 129, 30,
                      4, 55, 12, 129, 52, 17, 129, 50, 20, 129, 48, 24, 129,
                      46, 27, 129, 44, 21, 69, 6, 129, 41, 22, 70, 6, 80, 4,
                      129, 30, 4, 39, 21, 72, 6, 80, 4, 129, 30, 4, 36, 22, 73,
                      11, 129, 30, 26, 75, 9, 129, 30, 23, 76, 8, 129, 30, 21,
                      78, 6, 129, 30, 19, 79, 5, 129, 30, 16, 80, 4, 129, 30,
                      14, 80, 4, 129, 30, 12, 129, 30, 10, 129, 30, 7, 129, 30,
                      5, 129, 30, 4, 130, 193],
                'l': [30, 4, 117, 4, 130, 30, 91, 136, 30, 4, 130, 193],
                'm': [30, 4, 80, 4, 130, 30, 54, 136, 30, 4, 72, 5, 129, 30,
                      4, 74, 5, 129, 75, 5, 129, 76, 5, 129, 30, 4, 75, 7, 129,
                      30, 4, 74, 9, 129, 30, 54, 132, 30, 53, 129, 30, 52, 129,
                      30, 51, 129, 30, 48, 129, 30, 4, 72, 5, 129, 30, 4, 74,
                      5, 129, 75, 5, 129, 76, 5, 129, 30, 4, 75, 7, 129, 30, 4,
                      74, 9, 129, 30, 54, 132, 30, 53, 129, 30, 52, 129, 30,
                      51, 129, 30, 48, 129, 30, 4, 130, 193],
                'n': [30, 4, 80, 4, 130, 30, 54, 136, 30, 4, 72, 5, 129, 30,
                      4, 74, 5, 129, 75, 5, 129, 76, 5, 129, 76, 6, 129, 77, 6,
                      130, 77, 7, 130, 76, 8, 129, 30, 4, 75, 9, 129, 30, 4,
                      72, 12, 129, 30, 54, 129, 30, 53, 130, 30, 52, 129, 30,
                      51, 129, 30, 49, 129, 30, 46, 129, 30, 42, 129, 30, 4,
                      130, 193],
                'o': [48, 18, 129, 43, 28, 129, 41, 32, 129, 39, 36, 129, 37,
                      40, 129, 35, 44, 129, 34, 46, 129, 33, 13, 68, 13, 129,
                      32, 9, 73, 9, 129, 32, 7, 75, 7, 129, 31, 6, 77, 6, 129,
                      31, 5, 78, 5, 129, 30, 5, 79, 5, 129, 30, 4, 80, 4, 132,
                      30, 5, 79, 5, 130, 31, 5, 78, 5, 129, 31, 6, 77, 6, 129,
                      32, 7, 75, 7, 129, 32, 9, 73, 9, 129, 33, 13, 68, 13,
                      129, 34, 46, 129, 35, 44, 129, 37, 40, 129, 39, 36, 129,
                      41, 32, 129, 43, 28, 129, 48, 18, 129, 193],
                'p': [1, 3, 80, 4, 130, 1, 83, 137, 37, 5, 72, 5, 129, 35, 5,
                      74, 5, 129, 33, 5, 76, 5, 129, 32, 5, 77, 5, 129, 31, 5,
                      78, 5, 129, 31, 4, 79, 4, 129, 30, 5, 79, 5, 131, 30, 6,
                      78, 6, 129, 30, 7, 77, 7, 129, 31, 8, 75, 8, 129, 31, 11,
                      72, 11, 129, 32, 15, 67, 15, 129, 33, 48, 129, 34, 46,
                      129, 35, 44, 129, 37, 40, 129, 39, 36, 129, 42, 30, 129,
                      46, 22, 129, 193],
                'q': [46, 22, 129, 42, 30, 129, 39, 36, 129, 37, 40, 129, 35,
                      44, 129, 34, 46, 129, 33, 48, 129, 32, 15, 67, 15, 129,
                      31, 11, 72, 11, 129, 31, 8, 75, 8, 129, 30, 7, 77, 7,
                      129, 30, 6, 78, 6, 129, 30, 5, 79, 5, 131, 31, 4, 79, 4,
                      129, 31, 5, 78, 5, 129, 32, 5, 77, 5, 129, 33, 5, 76, 5,
                      129, 35, 5, 74, 5, 129, 37, 5, 72, 5, 129, 1, 83, 136, 1,
                      3, 80, 4, 130, 193],
                'r': [30, 4, 80, 4, 130, 30, 54, 136, 30, 4, 68, 6, 129, 30,
                      4, 70, 6, 129, 71, 7, 129, 72, 7, 129, 73, 7, 129, 74, 7,
                      129, 74, 8, 129, 75, 8, 130, 69, 15, 129, 67, 17, 129,
                      66, 18, 129, 65, 19, 130, 65, 18, 130, 66, 16, 129, 67,
                      13, 129, 69, 8, 129, 193],
                's': [30, 13, 64, 8, 129, 30, 13, 61, 14, 129, 30, 13, 59, 18,
                      129, 30, 13, 57, 22, 129, 33, 8, 56, 24, 129, 32, 7, 55,
                      26, 129, 32, 6, 54, 28, 129, 31, 6, 53, 16, 77, 6, 129,
                      31, 5, 53, 14, 79, 4, 129, 30, 5, 52, 14, 80, 4, 129, 30,
                      5, 52, 13, 80, 4, 129, 30, 4, 52, 13, 80, 4, 129, 30, 4,
                      52, 12, 80, 4, 129, 30, 4, 51, 13, 80, 4, 130, 30, 4, 50,
                      13, 79, 5, 129, 30, 4, 50, 13, 78, 5, 129, 30, 5, 49, 14,
                      77, 6, 129, 31, 4, 49, 13, 76, 6, 129, 31, 5, 48, 14, 75,
                      7, 129, 32, 5, 47, 14, 73, 8, 129, 32, 6, 45, 16, 71, 13,
                      129, 33, 27, 71, 13, 129, 34, 26, 71, 13, 129, 35, 24,
                      71, 13, 129, 37, 20, 129, 39, 16, 129, 43, 9, 129, 193],
                't': [80, 4, 131, 41, 56, 129, 37, 60, 129, 35, 62, 129, 33,
                      64, 129, 32, 65, 129, 31, 66, 129, 30, 67, 130, 30, 11,
                      80, 4, 129, 30, 9, 80, 4, 129, 30, 8, 80, 4, 129, 31, 7,
                      80, 4, 129, 31, 6, 129, 32, 5, 129, 33, 5, 129, 35, 4,
                      129, 38, 3, 129, 193],
                'u': [80, 4, 130, 42, 42, 129, 38, 46, 129, 35, 49, 129, 33,
                      51, 129, 32, 52, 129, 31, 53, 130, 30, 54, 129, 30, 12,
                      129, 30, 9, 129, 30, 8, 129, 30, 7, 130, 31, 6, 130, 32,
                      6, 129, 33, 5, 129, 34, 5, 129, 35, 5, 80, 4, 129, 37, 5,
                      80, 4, 129, 30, 54, 136, 30, 4, 130, 193],
                'v': [80, 4, 130, 77, 7, 129, 74, 10, 129, 70, 14, 129, 66,
                      18, 129, 62, 22, 129, 59, 25, 129, 55, 29, 129, 51, 33,
                      129, 47, 37, 129, 44, 32, 80, 4, 129, 40, 32, 80, 4, 129,
                      36, 32, 129, 32, 33, 129, 30, 31, 129, 33, 24, 129, 36,
                      17, 129, 40, 12, 129, 44, 12, 129, 48, 12, 129, 51, 13,
                      129, 55, 13, 129, 59, 13, 80, 4, 129, 63, 13, 80, 4, 129,
                      67, 17, 129, 71, 13, 129, 74, 10, 129, 78, 6, 129, 80, 4,
                      131, 193],
                'w': [80, 4, 130, 77, 7, 129, 74, 10, 129, 70, 14, 129, 66,
                      18, 129, 62, 22, 129, 59, 25, 129, 55, 29, 129, 51, 33,
                      129, 47, 37, 129, 44, 32, 80, 4, 129, 40, 32, 80, 4, 129,
                      36, 32, 129, 32, 33, 129, 30, 31, 129, 33, 24, 129, 36,
                      17, 129, 40, 12, 129, 44, 12, 129, 47, 13, 129, 44, 20,
                      129, 40, 28, 129, 36, 31, 129, 32, 32, 129, 30, 30, 129,
                      33, 24, 129, 36, 17, 129, 40, 12, 129, 44, 12, 129, 48,
                      12, 129, 51, 13, 129, 55, 13, 129, 59, 13, 80, 4, 129,
                      63, 13, 80, 4, 129, 67, 17, 129, 71, 13, 129, 74, 10,
                      129, 78, 6, 129, 80, 4, 131, 193],
                'x': [30, 4, 80, 4, 130, 30, 4, 79, 5, 129, 30, 5, 77, 7, 129,
                      30, 6, 74, 10, 129, 30, 8, 72, 12, 129, 30, 11, 69, 15,
                      129, 30, 13, 67, 17, 129, 30, 4, 37, 8, 64, 20, 129, 30,
                      4, 39, 8, 62, 22, 129, 41, 8, 59, 25, 129, 43, 8, 57, 27,
                      129, 45, 8, 55, 22, 80, 4, 129, 47, 27, 80, 4, 129, 49,
                      23, 129, 47, 22, 129, 44, 23, 129, 42, 22, 129, 30, 4,
                      39, 27, 129, 30, 4, 37, 31, 129, 30, 27, 62, 8, 129, 30,
                      25, 64, 8, 129, 30, 22, 66, 8, 80, 4, 129, 30, 20, 68, 8,
                      80, 4, 129, 30, 17, 70, 8, 80, 4, 129, 30, 15, 73, 11,
                      129, 30, 12, 75, 9, 129, 30, 10, 77, 7, 129, 30, 7, 79,
                      5, 129, 30, 5, 80, 4, 129, 30, 4, 80, 4, 130, 193],
                'y': [4, 5, 80, 4, 129, 2, 9, 80, 4, 129, 1, 11, 77, 7, 129,
                      1, 12, 74, 10, 129, 1, 12, 70, 14, 129, 1, 12, 66, 18,
                      129, 1, 11, 62, 22, 129, 2, 9, 59, 25, 129, 4, 11, 55,
                      29, 129, 7, 12, 51, 33, 129, 10, 12, 47, 37, 129, 14, 12,
                      44, 32, 80, 4, 129, 17, 13, 40, 32, 80, 4, 129, 21, 13,
                      36, 32, 129, 25, 40, 129, 29, 32, 129, 33, 24, 129, 36,
                      17, 129, 40, 12, 129, 44, 12, 129, 48, 12, 129, 51, 13,
                      129, 55, 13, 129, 59, 13, 80, 4, 129, 63, 13, 80, 4, 129,
                      67, 17, 129, 71, 13, 129, 74, 10, 129, 78, 6, 129, 80, 4,
                      131, 193],
                'z': [30, 1, 71, 13, 129, 30, 3, 71, 13, 129, 30, 6, 71, 13,
                      129, 30, 9, 75, 9, 129, 30, 11, 77, 7, 129, 30, 14, 79,
                      5, 129, 30, 17, 79, 5, 129, 30, 19, 80, 4, 129, 30, 22,
                      80, 4, 129, 30, 25, 80, 4, 129, 30, 27, 80, 4, 129, 30,
                      4, 36, 24, 80, 4, 129, 30, 4, 38, 25, 80, 4, 129, 30, 4,
                      41, 24, 80, 4, 129, 30, 4, 44, 24, 80, 4, 129, 30, 4, 46,
                      25, 80, 4, 129, 30, 4, 49, 25, 80, 4, 129, 30, 4, 52, 24,
                      80, 4, 129, 30, 4, 54, 30, 129, 30, 4, 57, 27, 129, 30,
                      4, 59, 25, 129, 30, 4, 62, 22, 129, 30, 4, 65, 19, 129,
                      30, 5, 67, 17, 129, 30, 5, 70, 14, 129, 30, 7, 73, 11,
                      129, 30, 9, 76, 8, 129, 30, 13, 78, 6, 129, 30, 13, 81,
                      3, 129, 30, 13, 129, 193]}

# backup cow for when cowsay isn't set
DEFAULT_COW = """$the_cow = <<"EOC";
        $thoughts   ^__^
         $thoughts  ($eyes)\\_______
            (__)\\       )\\/\\
             $tongue ||----w |
                ||     ||
EOC"""

# translation rules for the swedish chef. bork bork bork!
BORK_RULES = [['an', 'un'], ['An', 'Un'], ['au', 'oo'], ['Au', 'Oo'],
              ["a([A-Za-z'])", r'e\1'], ["A([A-Za-z'])", r'E\1'],
              ["en([^A-Za-z'])", r'ee\1'], ['ew', 'oo'],
              ["e([^A-Za-z'])", r'e-a\1'], ['^e', 'i'], ['^E', 'I'],
              ['f', 'ff'], ['ir', 'ur'], ['i', 'ee'], ['ow', 'oo'],
              ['^o', 'oo'], ['^O', 'Oo'], ['o', 'u'], ['the', 'zee'],
              ['The', 'Zee'], ["th([^A-Za-z'])", r't\1'], ['tion', 'shun'],
              ['u', 'oo'], ['U', 'Oo'], ['v', 'f'], ['V', 'F'], ['w', 'v'],
              ['W', 'V']]

for i, rule in enumerate(BORK_RULES):
    BORK_RULES[i] = re.compile(rule[0]), rule[1]


# figlet translation maps
FIG_REV_MAP = {123: 125, 40: 41, 41: 40, 125: 123, 47: 92, 92: 47, 91: 93,
               60: 62, 93: 91, 62: 60}

FIG_FLIP_MAP = {65: 86, 98: 80, 118: 94, 119: 109, 109: 119, 77: 87, 47: 92,
                80: 98, 82: 98, 86: 65, 87: 77, 92: 47, 94: 118, 95: 45}

# standard font to fall back on if figlet isn't installed
STANDARD_FONT = (
        "flf2a$ 6 5 16 15 0 0 24463 229\n $@\n $@\n $@\n $@\n $@\n $@@\n  _ @"
        "\n | |@\n | |@\n |_|@\n (_)@\n    @@\n  _ _ @\n ( | )@\n  V V @\n   "
        "$  @\n   $  @\n      @@\n    _  _   @\n  _| || |_ @\n |_  ..  _|@\n "
        "|_      _|@\n   |_||_|  @\n           @@\n   _  @\n  | | @\n / __)@"
        "\n \\__ \\@\n (   /@\n  |_| @@\n  _  __@\n (_)/ /@\n   / / @\n  / /_"
        " @\n /_/(_)@\n       @@\n   ___   @\n  ( _ )  @\n  / _ \\/\\@\n | (_"
        ">  <@\n  \\___/\\/@\n         @@\n  _ @\n ( )@\n |/ @\n  $ @\n  $ @"
        "\n    @@\n   __@\n  / /@\n | | @\n | | @\n | | @\n  \\_\\@@\n __  @"
        "\n \\ \\ @\n  | |@\n  | |@\n  | |@\n /_/ @@\n       @\n __/\\__@\n "
        "\\    /@\n /_  _\\@\n   \\/  @\n       @@\n        @\n    _   @\n  _"
        "| |_ @\n |_   _|@\n   |_|  @\n        @@\n    @\n    @\n    @\n  _ @"
        "\n ( )@\n |/ @@\n        @\n        @\n  _____ @\n |_____|@\n    $  "
        " @\n        @@\n    @\n    @\n    @\n  _ @\n (_)@\n    @@\n     __@"
        "\n    / /@\n   / / @\n  / /  @\n /_/   @\n       @@\n   ___  @\n  / "
        "_ \\ @\n | | | |@\n | |_| |@\n  \\___/ @\n        @@\n  _ @\n / |@\n"
        " | |@\n | |@\n |_|@\n    @@\n  ____  @\n |___ \\ @\n   __) |@\n  / _"
        "_/ @\n |_____|@\n        @@\n  _____ @\n |___ / @\n   |_ \\ @\n  ___"
        ") |@\n |____/ @\n        @@\n  _  _   @\n | || |  @\n | || |_ @\n |_"
        "_   _|@\n    |_|  @\n         @@\n  ____  @\n | ___| @\n |___ \\ @\n"
        "  ___) |@\n |____/ @\n        @@\n   __   @\n  / /_  @\n | '_ \\ @\n"
        " | (_) |@\n  \\___/ @\n        @@\n  _____ @\n |___  |@\n    / / @\n"
        "   / /  @\n  /_/   @\n        @@\n   ___  @\n  ( _ ) @\n  / _ \\ @\n"
        " | (_) |@\n  \\___/ @\n        @@\n   ___  @\n  / _ \\ @\n | (_) |@"
        "\n  \\__, |@\n    /_/ @\n        @@\n    @\n  _ @\n (_)@\n  _ @\n (_"
        ")@\n    @@\n    @\n  _ @\n (_)@\n  _ @\n ( )@\n |/ @@\n   __@\n  / /"
        "@\n / / @\n \\ \\ @\n  \\_\\@\n     @@\n        @\n  _____ @\n |____"
        "_|@\n |_____|@\n    $   @\n        @@\n __  @\n \\ \\ @\n  \\ \\@\n "
        " / /@\n /_/ @\n     @@\n  ___ @\n |__ \\@\n   / /@\n  |_| @\n  (_) @"
        "\n      @@\n    ____  @\n   / __ \\ @\n  / / _` |@\n | | (_| |@\n  "
        "\\ \\__,_|@\n   \\____/ @@\n     _    @\n    / \\   @\n   / _ \\  @"
        "\n  / ___ \\ @\n /_/   \\_\\@\n          @@\n  ____  @\n | __ ) @\n "
        "|  _ \\ @\n | |_) |@\n |____/ @\n        @@\n   ____ @\n  / ___|@\n "
        "| |    @\n | |___ @\n  \\____|@\n        @@\n  ____  @\n |  _ \\ @\n"
        " | | | |@\n | |_| |@\n |____/ @\n        @@\n  _____ @\n | ____|@\n "
        "|  _|  @\n | |___ @\n |_____|@\n        @@\n  _____ @\n |  ___|@\n |"
        " |_   @\n |  _|  @\n |_|    @\n        @@\n   ____ @\n  / ___|@\n | "
        "|  _ @\n | |_| |@\n  \\____|@\n        @@\n  _   _ @\n | | | |@\n | "
        "|_| |@\n |  _  |@\n |_| |_|@\n        @@\n  ___ @\n |_ _|@\n  | | @"
        "\n  | | @\n |___|@\n      @@\n      _ @\n     | |@\n  _  | |@\n | |_"
        "| |@\n  \\___/ @\n        @@\n  _  __@\n | |/ /@\n | ' / @\n | . \\ "
        "@\n |_|\\_\\@\n       @@\n  _     @\n | |    @\n | |    @\n | |___ @"
        "\n |_____|@\n        @@\n  __  __ @\n |  \\/  |@\n | |\\/| |@\n | | "
        " | |@\n |_|  |_|@\n         @@\n  _   _ @\n | \\ | |@\n |  \\| |@\n "
        "| |\\  |@\n |_| \\_|@\n        @@\n   ___  @\n  / _ \\ @\n | | | |@"
        "\n | |_| |@\n  \\___/ @\n        @@\n  ____  @\n |  _ \\ @\n | |_) |"
        "@\n |  __/ @\n |_|    @\n        @@\n   ___  @\n  / _ \\ @\n | | | |"
        "@\n | |_| |@\n  \\__\\_\\@\n        @@\n  ____  @\n |  _ \\ @\n | |_"
        ") |@\n |  _ < @\n |_| \\_\\@\n        @@\n  ____  @\n / ___| @\n \\_"
        "__ \\ @\n  ___) |@\n |____/ @\n        @@\n  _____ @\n |_   _|@\n   "
        "| |  @\n   | |  @\n   |_|  @\n        @@\n  _   _ @\n | | | |@\n | |"
        " | |@\n | |_| |@\n  \\___/ @\n        @@\n __     __@\n \\ \\   / /@"
        "\n  \\ \\ / / @\n   \\ V /  @\n    \\_/   @\n          @@\n __      "
        "  __@\n \\ \\      / /@\n  \\ \\ /\\ / / @\n   \\ V  V /  @\n    \\_"
        "/\\_/   @\n             @@\n __  __@\n \\ \\/ /@\n  \\  / @\n  /  \\"
        " @\n /_/\\_\\@\n       @@\n __   __@\n \\ \\ / /@\n  \\ V / @\n   | "
        "|  @\n   |_|  @\n        @@\n  _____@\n |__  /@\n   / / @\n  / /_ @"
        "\n /____|@\n       @@\n  __ @\n | _|@\n | | @\n | | @\n | | @\n |__|"
        "@@\n __    @\n \\ \\   @\n  \\ \\  @\n   \\ \\ @\n    \\_\\@\n      "
        " @@\n  __ @\n |_ |@\n  | |@\n  | |@\n  | |@\n |__|@@\n  /\\ @\n |/\\"
        "|@\n   $ @\n   $ @\n   $ @\n     @@\n        @\n        @\n        @"
        "\n        @\n  _____ @\n |_____|@@\n  _ @\n ( )@\n  \\|@\n  $ @\n  $"
        " @\n    @@\n        @\n   __ _ @\n  / _` |@\n | (_| |@\n  \\__,_|@\n"
        "        @@\n  _     @\n | |__  @\n | '_ \\ @\n | |_) |@\n |_.__/ @\n"
        "        @@\n       @\n   ___ @\n  / __|@\n | (__ @\n  \\___|@\n     "
        "  @@\n      _ @\n   __| |@\n  / _` |@\n | (_| |@\n  \\__,_|@\n      "
        "  @@\n       @\n   ___ @\n  / _ \\@\n |  __/@\n  \\___|@\n       @@"
        "\n   __ @\n  / _|@\n | |_ @\n |  _|@\n |_|  @\n      @@\n        @\n"
        "   __ _ @\n  / _` |@\n | (_| |@\n  \\__, |@\n  |___/ @@\n  _     @\n"
        " | |__  @\n | '_ \\ @\n | | | |@\n |_| |_|@\n        @@\n  _ @\n (_)"
        "@\n | |@\n | |@\n |_|@\n    @@\n    _ @\n   (_)@\n   | |@\n   | |@\n"
        "  _/ |@\n |__/ @@\n  _    @\n | | __@\n | |/ /@\n |   < @\n |_|\\_\\"
        "@\n       @@\n  _ @\n | |@\n | |@\n | |@\n |_|@\n    @@\n           "
        " @\n  _ __ ___  @\n | '_ ` _ \\ @\n | | | | | |@\n |_| |_| |_|@\n   "
        "         @@\n        @\n  _ __  @\n | '_ \\ @\n | | | |@\n |_| |_|@"
        "\n        @@\n        @\n   ___  @\n  / _ \\ @\n | (_) |@\n  \\___/ "
        "@\n        @@\n        @\n  _ __  @\n | '_ \\ @\n | |_) |@\n | .__/ "
        "@\n |_|    @@\n        @\n   __ _ @\n  / _` |@\n | (_| |@\n  \\__, |"
        "@\n     |_|@@\n       @\n  _ __ @\n | '__|@\n | |   @\n |_|   @\n   "
        "    @@\n      @\n  ___ @\n / __|@\n \\__ \\@\n |___/@\n      @@\n  _"
        "   @\n | |_ @\n | __|@\n | |_ @\n  \\__|@\n      @@\n        @\n  _ "
        "  _ @\n | | | |@\n | |_| |@\n  \\__,_|@\n        @@\n        @\n __ "
        "  __@\n \\ \\ / /@\n  \\ V / @\n   \\_/  @\n        @@\n           @"
        "\n __      __@\n \\ \\ /\\ / /@\n  \\ V  V / @\n   \\_/\\_/  @\n    "
        "       @@\n       @\n __  __@\n \\ \\/ /@\n  >  < @\n /_/\\_\\@\n   "
        "    @@\n        @\n  _   _ @\n | | | |@\n | |_| |@\n  \\__, |@\n  |_"
        "__/ @@\n      @\n  ____@\n |_  /@\n  / / @\n /___|@\n      @@\n    _"
        "_@\n   / /@\n  | | @\n < <  @\n  | | @\n   \\_\\@@\n  _ @\n | |@\n |"
        " |@\n | |@\n | |@\n |_|@@\n __   @\n \\ \\  @\n  | | @\n   > >@\n  |"
        " | @\n /_/  @@\n  /\\/|@\n |/\\/ @\n   $  @\n   $  @\n   $  @\n     "
        " @@\n")


class FigletFont(object):

    """This class represents the currently loaded figlet font, including
    meta-data about how it should be displayed"""

    magic_number_re = re.compile(r'^flf2.')
    end_marker_re = re.compile(r'(.)\s*$')

    def __init__(self, prefix='.', font='standard'):
        self.prefix = prefix
        self.font = font
        self.chars = {}
        self.width = {}
        self.data = None

        font_path = '%s/%s.flf' % (self.prefix, self.font)
        if not os.path.exists(font_path):
            self.data = STANDARD_FONT
        else:
            with open(font_path, 'r') as fp:
                self.data = fp.read()

        try:
            # Parse first line of file, the header
            data = self.data.splitlines()

            header = data.pop(0)
            if not self.magic_number_re.search(header):
                raise Exception('%s is not a valid figlet font' % font_path)

            header = self.magic_number_re.sub('', header)
            header = header.split()

            if len(header) < 6:
                raise Exception('malformed header for %s' % font_path)

            hard_blank = header[0]
            height, _, _, old_layout, comment_lines = map(int, header[1:6])
            print_dir = full_layout = None

            # these are all optional for backwards compat
            if len(header) > 6:
                print_dir = int(header[6])
            if len(header) > 7:
                full_layout = int(header[7])

            # if the new layout style isn't available,
            # convert old layout style. backwards compatability
            if not full_layout:
                if old_layout == 0:
                    full_layout = 64
                elif old_layout < 0:
                    full_layout = 0
                else:
                    full_layout = (old_layout & 31) | 128

            # Some header information is stored for later, the rendering
            # engine needs to know this stuff.
            self.height = height
            self.hard_blank = hard_blank
            self.print_dir = print_dir
            self.smush_mode = full_layout

            # Strip out comment lines
            data = data[comment_lines:]

            # Load characters
            for i in xrange(32, 127):
                end = None
                width = 0
                chars = []
                for j in xrange(height):
                    line = data.pop(0)
                    if not end:
                        end = self.end_marker_re.search(line).group(1)
                        end = re.compile(re.escape(end) + r'{1,2}$')
                    line = end.sub('', line)
                    if len(line) > width:
                        width = len(line)
                    chars.append(line)
                if chars:
                    self.chars[i] = chars
                    self.width[i] = width

        except Exception, error:
            raise Exception('parse error: %s' % error)


class FigletRenderingEngine(object):

    """This class handles the rendering of a FigletFont, including
    smushing/kerning/justification/direction"""

    SM_EQUAL = 1       # smush equal chars (not hardblanks)
    SM_LOWLINE = 2     # smush _ with any char in hierarchy
    SM_HIERARCHY = 4   # hierarchy: |, /\, [], {}, (), <>
    SM_PAIR = 8        # hierarchy: [ + ] -> |, { + } -> |, ( + ) -> |
    SM_BIGX = 16       # / + \ -> X, > + < -> X
    SM_HARDBLANK = 32  # hardblank + hardblank -> hardblank
    SM_KERN = 64
    SM_SMUSH = 128

    def __init__(self, base):
        self.base = base

    def smush_chars(self, left='', right=''):
        """
        Given 2 characters which represent the edges of rendered figlet
        fonts where they would touch, see if they can be smushed together.
        Returns None if this cannot or should not be done.
        """
        if left.isspace():
            return right
        if right.isspace():
            return left

        # disallows overlapping if previous or current char are short
        if (self.prev_width < 2) or (self.cur_width < 2):
            return

        # kerning only
        if not self.base.Font.smush_mode & self.SM_SMUSH:
            return

        # smushing by universal overlapping
        if not self.base.Font.smush_mode & 63:
            # ensure preference to visible characters.
            if left == self.base.Font.hard_blank:
                return right
            if right == self.base.Font.hard_blank:
                return left

            # ensures that the dominant (foreground)
            # fig-character for overlapping is the latter in the
            # user's text, not necessarily the rightmost character.
            return left if self.base.direction == 'right-to-left' else right

        if self.base.Font.smush_mode & self.SM_HARDBLANK:
            if (left == self.base.Font.hard_blank and
                right == self.base.Font.hard_blank):
                return left

        if (left == self.base.Font.hard_blank or
            right == self.base.Font.hard_blank):
            return

        if self.base.Font.smush_mode & self.SM_EQUAL:
            if left == right:
                return left

        if self.base.Font.smush_mode & self.SM_LOWLINE:
            if left == '_' and right.plain in r'|/\[]{}()<>':
                return right
            if right == '_' and left.plain in r'|/\[]{}()<>':
                return left

        if self.base.Font.smush_mode & self.SM_HIERARCHY:
            if left == '|' and right.plain in r'|/\[]{}()<>':
                return right
            if right == '|' and left.plain in r'|/\[]{}()<>':
                return left
            if left.plain in r'\/' and right.plain in '[]{}()<>':
                return right
            if right.plain in r'\/' and left.plain in '[]{}()<>':
                return left
            if left.plain in '[]' and right.plain in '{}()<>':
                return right
            if right.plain in '[]' and left.plain in '{}()<>':
                return left
            if left.plain in '{}' and right.plain in '()<>':
                return right
            if right.plain in '{}' and left.plain in '()<>':
                return left
            if left.plain in '()' and right.plain in '<>':
                return right
            if right.plain in '()' and left.plain in '<>':
                return left

        if self.base.Font.smush_mode & self.SM_PAIR:
            for pair in [left + right, right + left]:
                if pair in ['[]', '{}', '()']:
                    return '|'

        if self.base.Font.smush_mode & self.SM_BIGX:
            if left == '/' and right == '\\':
                return '|'
            if right == '/' and left == '\\':
                return 'Y'
            if left == '>' and right == '<':
                return 'X'

    def smush_amount(self, left=None, right=None, buf=None, cur_char=None):
        """
        Calculate the amount of smushing we can do between this char and
        the last.  If this is the first char it will throw a series of
        exceptions which are caught and cause appropriate values to be
        set for later.  This differs from C figlet which will just get
        bogus values from memory and then discard them after.
        """
        if buf is None:
            buf = []
        if cur_char is None:
            cur_char = []
        if not self.base.Font.smush_mode & (self.SM_SMUSH | self.SM_KERN):
            return 0
        max_smush = self.cur_width
        for row in xrange(self.base.Font.height):
            line_left = buf[row]
            line_right = cur_char[row]
            if self.base.direction == 'right-to-left':
                line_left, line_right = line_right, line_left
            try:
                linebd = len(line_left.rstrip()) - 1
                if linebd < 0:
                    linebd = 0
                ch1 = line_left[linebd]
            except:
                linebd = 0
                ch1 = ''
            try:
                charbd = len(line_right) - len(line_right.lstrip())
                ch2 = line_right[charbd]
            except:
                charbd = len(line_right)
                ch2 = ''
            amt = charbd + len(line_left) - 1 - linebd
            if not ch1 or ch1 == ' ':
                amt += 1
            elif ch2 and self.smush_chars(ch1, ch2):
                amt += 1
            if amt < max_smush:
                max_smush = amt
        return max_smush

    def render(self, text):
        """Render an ASCII text string in figlet"""
        self.cur_width = self.prev_width = 0
        buf = []
        for ch in text:
            c = ord(ch.plain)
            if c not in self.base.Font.chars:
                continue
            cur_char = self.base.Font.chars[c]
            cur_char = [colstr(plain).fill(ch.colmap) for plain in cur_char]
            self.cur_width = self.base.Font.width[c]
            if not len(buf):
                buf = ['' for i in xrange(self.base.Font.height)]
            max_smush = self.smush_amount(buf=buf, cur_char=cur_char)

            # add a character to the buf and do smushing/kerning
            for row in xrange(self.base.Font.height):
                add_left = buf[row]
                add_right = cur_char[row]
                if self.base.direction == 'right-to-left':
                    add_left, add_right = add_right, add_left
                for i in xrange(max_smush):
                    try:
                        left = add_left[len(add_left) - max_smush + i]
                    except:
                        left = colstr()
                    right = add_right[i]
                    smushed = self.smush_chars(left, right)
                    try:
                        l = list(add_left)
                        l[len(l) - max_smush + i] = smushed
                        add_left = colstr().join(l)
                    except:
                        pass
                buf[row] = colstr(add_left) + add_right[max_smush:]
            self.prev_width = self.cur_width

        # justify text. This does not use str.rjust/str.center
        # specifically because the output would not match FIGlet
        if self.base.justify == 'right':
            for row in xrange(self.base.Font.height):
                buf[row] = (' ' * (self.base.width - len(buf[row]) - 1) +
                            buf[row])
        elif self.base.justify == 'center':
            for row in xrange(self.base.Font.height):
                buf[row] = (' ' * int((self.base.width - len(buf[row])) /
                            2) + buf[row])

        return [line.replace(self.base.Font.hard_blank, ' ') for line in buf]


class Figlet(object):

    """Main figlet class"""

    def __init__(self, prefix, font='standard', direction='auto',
                 justify='auto', width=80):
        self.prefix = prefix
        self.font = font
        self._direction = direction
        self._justify = justify
        self.width = width
        self.Font = FigletFont(prefix=self.prefix, font=self.font)
        self.engine = FigletRenderingEngine(base=self)

    @property
    def direction(self):
        if self._direction == 'auto':
            direction = self.Font.print_dir
            if direction:
                return 'right-to-left'
            else:
                return 'left-to-right'
        else:
            return self._direction

    @property
    def justify(self):
        if self._justify == 'auto':
            if self.direction == 'left-to-right':
                return 'left'
            elif self.direction == 'right-to-left':
                return 'right'
        else:
            return self._justify

    def render(self, text):
        return self.engine.render(text)


def coerce(func):

    """Internal: decorator to coerce all args and keyword args that are
    bare strings into colstr objects, inheriting their properties from
    the original.  This operation is recursive on all nested primitive
    data types except for the keys of dictionaries, since this would
    cause undefined and unexpected lookup behavior, as well as breaking
    keyword arguments.

    This decorator should be applied to any function who may be taking
    strings as parameters so that our functions can always assume they
    have colstr objects to work with and that they are properly
    decoded."""

    def conv(item, opts):
        """Recursive converstion function"""
        if isinstance(item, basestring):
            return colstr(item, **opts)
        if isinstance(item, tuple):
            return tuple(conv(x, opts) for x in item)
        if isinstance(item, list):
            return list(conv(x, opts) for x in item)
        if isinstance(item, dict):
            return dict((x, conv(y, opts)) for x, y in item.iteritems())
            #return dict(conv(x, opts) for x in item.iteritems())
        return item

    def inner(self, *args, **kwargs):
        """Wrapper function"""
        # none of these are auto-detected in a useful way, so best
        # inherit them from someone that knows wtf is going on.
        opts = {'encoding': self.encoding, 'errors': self.errors,
                'newline': self.newline}
        args = conv(args, opts)
        kwargs = conv(kwargs, opts)
        return func(self, *args, **kwargs)

    # lie about who we are so that help() is still useful
    inner.__name__ = func.__name__
    inner.__doc__ = func.__doc__
    return inner


class colstr(object):

    """colstr([string [, encoding[, scheme[, errors[, newline]]]]]) -> object

    Create a new color-mapped Unicode object from the given string.
    encoding defaults to the current default string encoding.  scheme
    can be 'ansi', 'mirc' or 'plain' and defaults to auto-detect.
    errors can be 'strict', 'replace' or 'ignore' and defaults to
    'strict'.  newline style can be 'reset' or 'ignore' and indicate
    whether color gets reset to its default on a new line (such as IRC)
    or if the color it was changed to continues (some shells).  default
    is 'reset'.

    The colstr object can be manipulated like regular unicode objects
    while keeping the underlyingn color information in tact.  Call the
    render() method to encode into ANSI or mIRC colors."""

    # mapping by color name
    colnames = ['black',    # 0
                'red',      # 1
                'green',    # 2
                'yellow',   # 3
                'blue',     # 4
                'magenta',  # 5
                'cyan',     # 6
                'white']    # 7

    # mapping by color code (uppercase = intensity on)
    codes = ['d', 'r', 'g', 'y', 'b', 'm', 'c', 'w']

    # structural data for various color schemes
    schemes = {'mirc': {'color_re': re.compile('(\x03[0-9,]+\x16*|\x0f)'),
                        'parse_re': re.compile('\x03([0-9]+)?(?:,([0-9]+))?'),
                        # map mirc colors to ansi intense/color codes
                        'map': [(1, 7),    # 0
                                (0, 0),    # 1
                                (0, 4),    # 2
                                (0, 2),    # 3
                                (1, 1),    # 4
                                (0, 1),    # 5
                                (0, 5),    # 6
                                (0, 3),    # 7
                                (1, 3),    # 8
                                (1, 2),    # 9
                                (0, 6),    # 10
                                (1, 6),    # 11
                                (1, 4),    # 12
                                (1, 5),    # 13
                                (1, 0),    # 14
                                (0, 7)]},  # 15
               'ansi': {'color_re': re.compile('(\x1b\[[0-9;]+m)'),
                        'parse_re': re.compile('\x1b\[([0-9;]+)')},
               # dummy entry to handle uncolored text
               'plain': {'color_re': re.compile('(\xff)'),
                         'parse_re': re.compile('(\xff)')}}

    # the default color scheme (white on black)
    reset = (7,  # foreground color
             0,  # intensity on
             0,  # background color
             1)  # default flag indicates color has not changed

    newline_re = re.compile(r'(\n)')

    # this evil little thing parses python old-style string modulo formats
    # http://docs.python.org/3.0/library/stdtypes.html
    fmt_re = re.compile(r'''%                     # start of format option
                            (?:\((.*?)\))?        # optional mapping key
                            ([#0 +-]*?)           # optional conversion flags
                            (\*|[0-9]+?)?         # optional field width
                            (?:\.(\*|[0-9]+?))?   # optional precision
                            [hlL]?                # ignored length modifier
                            ([diouxXeEfFgGcrs%])  # conversion type
                            ''', re.VERBOSE)


    def __init__(self, string=None, encoding=None, scheme=None, errors=None,
                 newline='reset'):
        if encoding is None:
            encoding = sys.getdefaultencoding()
        if errors is None:
            errors = 'strict'
        if string is None:
            string = u''
        elif isinstance(string, colstr):
            self.__dict__.update(string.__dict__)
            return
        elif not isinstance(string, unicode):
            string = unicode(string, encoding, errors)
        if scheme is None:
            scheme = self.detect(string)
        if newline not in ('reset', 'ignore'):
            raise ValueError("newline style must be 'reset' or 'ignore'")
        self.plain, self.colmap = self.decode(string, scheme, newline)
        self.encoding = encoding
        self.scheme = scheme
        self.errors = errors
        self.newline = newline

    def render(self, scheme=None):
        """self.render([scheme]) -> unicode

        Renders the colstr object into unicode with the color data for
        the given scheme added."""
        if scheme is None:
            scheme = self.scheme
        return self.encode(self.plain, self.colmap, scheme)

    def clone(self, plain=None, colmap=None):
        """Create a new instance of the same colstr.  Initial values for
        plain and/or colmap may be provided.  If plain is larger than the
        colormap, it will be padding with default values.  If colmap is larger,
        it will be truncated to fit"""
        new = colstr(self)
        if plain is not None:
            new.plain = plain
        if colmap is not None:
            new.colmap = colmap
        offset = len(new.plain) - len(new.colmap)
        if offset > 0:
            # plain is larger than colmap, add defaults to colmap
            new.colmap += self.reset_char * offset
        elif offset < 0:
            # colamp is larger than plain, chomp chomp
            new.colmap = new.colmap[:offset]
        # assert the above worked
        if len(new.plain) != len(new.colmap):
            raise ValueError('plain/colmap size mismatch')
        return new

    @property
    def reset_char(self):
        """Packed reset character"""
        return self.pack(*self.reset)

    @property
    def nocolor_char(self):
        """Packed do-not-color character"""

        # pretty much any color combination is invalid if the
        # default flag is set, this one is given special significance
        # for apps because it packs to \xFF.
        return self.pack(7, 1, 7, 1)

    @classmethod
    def detect(cls, string):
        """Try to guess color scheme from the given seq of raw bytes"""
        seen = {}
        for scheme, data in cls.schemes.iteritems():
            seen[scheme] = len(data['color_re'].findall(string))
        if sum(seen.values()):
            return max(seen.iteritems(), key=lambda item: item[1])[0]
        return 'plain'

    @classmethod
    def decode(cls, data, scheme, newline='reset'):
        """Returns decoded plain text and its colormap from text"""

        # sanity check inputs
        if not isinstance(data, unicode):
            raise TypeError('decode requires unicode data')
        if scheme not in cls.schemes:
            raise ValueError('unknown scheme: %s' % scheme)

        # decode
        plain = []
        colmap = []
        attrs = cls.schemes[scheme]
        fg, intense, bg, default = cls.reset
        for cpart in attrs['color_re'].split(data):
            for part in cls.newline_re.split(cpart):
                if not part:
                    continue
                if attrs['color_re'].match(part):
                    if part == '\x0f':
                        fg, intense, bg, default = cls.reset
                    else:
                        part = attrs['parse_re'].search(part).groups()
                        default = 0
                        if scheme == 'mirc':
                            new_fg, new_bg = part
                            if new_fg is not None:
                                intense, fg = attrs['map'][int(new_fg)]
                            if new_bg is not None:
                                bg = attrs['map'][int(new_bg)][1]
                        elif scheme == 'ansi':
                            for part in [int(i) for i in part[0].split(';')]:
                                if part == 0:
                                    fg, intense, bg, default = cls.reset
                                elif part == 1:
                                    intense = 1
                                elif part in (2, 22):
                                    intense = 0
                                elif part == 39:
                                    fg = cls.reset[0]
                                elif part == 49:
                                    bg = cls.reset[2]
                                elif part >= 30:
                                    part -= 30
                                    if part >= 10:
                                        bg = part - 10
                                    else:
                                        fg = part
                else:
                    if newline == 'reset' and part == '\n':
                        fg, intense, bg, default = cls.reset
                    plain.append(part)
                    col = cls.pack(fg, intense, bg, default)
                    colmap.append(col * len(part))
        return u''.join(plain), ''.join(colmap)

    @classmethod
    def encode(cls, plain, colmap, scheme):
        """Encode the plain/colmap pair in color using provided scheme"""

        # sanity check inputs
        if scheme not in cls.schemes:
            raise ValueError('unknown scheme: %s' % scheme)

        # encode
        attrs = cls.schemes[scheme]
        output = []
        last = list(cls.reset)
        for i, zipped in enumerate(zip(plain, colmap)):
            ch, col = zipped[0], list(cls.unpack(zipped[1]))
            try:
                next = plain[i + 1]
            except IndexError:
                next = None

            # what's changed?
            fg_changed = col[0] != last[0]
            intense_changed = col[1] != last[1]
            bg_changed = col[2] != last[2]

            # the conditions under which we will need to repaint
            if bg_changed or (ch != ' ' and (fg_changed or intense_changed)):
                outcol = None
                if scheme == 'mirc':
                    if col[3]:
                        outcol = '\x0f'
                    else:
                        codes = []
                        if fg_changed or intense_changed:
                            newcol = attrs['map'].index((col[1], col[0]))
                            codes.append("%02d" % (newcol,))
                        if bg_changed:
                            if not codes:
                                codes.append('')
                            newcol = attrs['map'].index((0, col[2]))
                            codes.append("%02d" % (newcol,))
                        outcol = '\x03%s' % ','.join(codes)
                        if next and next.isdigit():
                            outcol += '\x16\x16'
                elif scheme == 'ansi':
                    codes = []
                    if col[3]:
                        codes.append(0)
                    else:
                        if fg_changed:
                            codes.append(col[0] + 30)
                        if bg_changed:
                            codes.append(col[2] + 40)
                        if intense_changed:
                            if col[1]:
                                codes.append(1)
                            else:
                                codes.append(22)
                    outcol = '\x1b[%sm' % ';'.join(map(str, codes))
                if outcol:
                    last = col
                    output.append(outcol)

            output.append(ch)
        return u''.join(output)

    @staticmethod
    def pack(fg, intense=0, bg=0, default=1):
        """Pack color -> char"""
        return chr(fg + (intense << 3) + (bg << 4) + (default << 7))

    @staticmethod
    def unpack(char):
        """Unpack color -> (fg, intense, bg, default)"""
        char = ord(char)
        return ((char & 7), (char & 8) >> 3,
                (char & 112) >> 4, (char & 128) >> 7)

    def fill(S, bg):
        """Returns new colstr with color filled with bg"""
        return S.clone(None, bg * len(S))

    @classmethod
    def compile(cls, map):
        """Compile a letter-coded map into packed version"""
        compiled = []
        for ch in map:
            if ch.isupper():
                intense = 1
                ch = ch.lower()
            else:
                intense = 0
            compiled.append(cls.pack(cls.codes.index(ch), intense, default=0))
        return ''.join(compiled)

    @classmethod
    def pack_by_name(cls, name):
        """Return the packed color value by name"""

        # XXX this whole function should be greatly simplified..
        # but at least it works, will be useful somewhere i think.
        name = name.lower()
        name = name.replace('dark', '')
        name = name.replace('light', 'bright')
        name = name.replace('gray', 'grey')
        name = name.replace('orange', 'bright red')
        name = name.replace('purple', 'magenta')
        name = name.split()
        if 'on' not in name:
            name += ['on', 'black']
        on = name.index('on')

        # grey -> bright black
        # bright grey -> white
        # white -> bright white
        def fixgrey(words):
            if 'grey' in words:
                if 'bright' in words:
                    return ['white']
                else:
                    return ['bright', 'black']
            elif 'white' in words:
                return ['bright', 'white']
            else:
                return words

        fg, intense, bg, default = cls.reset
        for word in fixgrey(name[:on]):
            if word == 'bright':
                intense = 1
                default = 0
            elif word in cls.colnames:
                fg = cls.colnames.index(word)
                default = 0
        for word in fixgrey(name[on + 1:]):
            if word in cls.colnames:
                bg = cls.colnames.index(word)
                default = 0

        char = cls.pack(fg, intense, bg, default)
        return char

    def __str__(self):
        """x.__str__() <==> str(x)"""
        return self.plain
        #return self.render('ansi').encode('utf8', 'replace')

    def __repr__(self):
        return repr(self.plain).replace('u', 'c', 1)

    def __iter__(self):
        for i in xrange(len(self)):
            yield self[i]

    def __mul__(x, n):
        """x.__mul__(n) <==> x*n"""
        return x.clone(x.plain * n, x.colmap * n)

    __rmul__ = __mul__

    def __len__(x):
        """x.__len__() <==> len(x)"""
        return len(x.plain)

    def __getitem__(x, y):
        """x.__getitem__(y) <==> x[y]"""
        return x.clone(x.plain[y], x.colmap[y])

    def __getslice__(x, i, j):
        """x.__getslice__(i, j) <==> x[i:j]"""
        return x.clone(x.plain[i:j], x.colmap[i:j])

    @coerce
    def __add__(x, y):
        """x.__add__(y) <==> x+y"""
        return x.clone(x.plain + y.plain, x.colmap + y.colmap)

    def capitalize(S):
        """S.capitalize() -> colstr

        Return a capitalized version of S, i.e. make the first character
        have upper case."""
        return S.clone(S.plain.capitalize())

    def lower(S):
        """S.lower() -> colstr

        Return a copy of the string S converted to lowercase."""
        return S.clone(S.plain.lower())

    def upper(S):
        """S.upper() -> colstr

        Return a copy of S converted to uppercase."""
        return S.clone(S.plain.upper())

    def swapcase(S):
        """S.swapcase() -> colstr

        Return a copy of S with uppercase characters converted to lowercase
        and vice versa."""
        return S.clone(S.plain.swapcase())

    def title(S):
        """S.title() -> colstr

        Return a titlecased version of S, i.e. words start with title case
        characters, all remaining cased characters have lower case."""
        return S.clone(S.plain.title())

    def isalnum(S):
        """S.isalnum() -> bool

        Return True if all characters in S are alphanumeric
        and there is at least one character in S, False otherwise."""
        return S.plain.isalnum()

    def isalpha(S):
        """S.isalpha() -> bool

        Return True if all characters in S are alphabetic
        and there is at least one character in S, False otherwise."""
        return S.plain.isalpha()

    def isdecimal(S):
        """S.isdecimal() -> bool

        Return True if there are only decimal characters in S,
        False otherwise."""
        return S.plain.isdecimal()

    def isdigit(S):
        """S.isdigit() -> bool

        Return True if all characters in S are digits
        and there is at least one character in S, False otherwise."""
        return S.plain.isdigit()

    def islower(S):
        """S.islower() -> bool

        Return True if all cased characters in S are lowercase and there is
        at least one cased character in S, False otherwise."""
        return S.plain.islower()

    def isnumeric(S):
        """S.isnumeric() -> bool

        Return True if there are only numeric characters in S,
        False otherwise."""
        return S.plain.isnumeric()

    def isspace(S):
        """S.isspace() -> bool

        Return True if all characters in S are whitespace
        and there is at least one character in S, False otherwise."""
        return S.plain.isspace()

    def istitle(S):
        """S.istitle() -> bool

        Return True if S is a titlecased string and there is at least one
        character in S, i.e. upper- and titlecase characters may only
        follow uncased characters and lowercase characters only cased ones.
        Return False otherwise."""
        return S.plain.istitle()

    def isupper(S):
        """S.isupper() -> bool

        Return True if all cased characters in S are uppercase and there is
        at least one cased character in S, False otherwise."""
        return S.plain.isupper()

    @coerce
    def startswith(S, prefix, *args):
        """S.startswith(prefix[, start[, end]]) -> bool

        Return True if S starts with the specified prefix, False otherwise.
        With optional start, test S beginning at that position.
        With optional end, stop comparing S at that position.
        prefix can also be a tuple of strings to try."""
        return S.plain.startswith(prefix.plain, *args)

    @coerce
    def endswith(S, suffix, *args):
        """S.endswith(suffix[, start[, end]]) -> bool

        Return True if S ends with the specified suffix, False otherwise.
        With optional start, test S beginning at that position.
        With optional end, stop comparing S at that position.
        suffix can also be a tuple of strings to try."""
        return S.plain.endswith(suffix.plain, *args)

    @coerce
    def __contains__(x, y):
        """x.__contains__(y) <==> y in x"""
        return y.plain in x.plain

    @coerce
    def __eq__(x, y):
        """x.__eq__(y) <==> x==y"""
        return x.plain == y.plain

    @coerce
    def __ge__(x, y):
        """x.__ge__(y) <==> x>=y"""
        return x.plain >= y.plain

    @coerce
    def __gt__(x, y):
        """x.__gt__(y) <==> x>y"""
        return x.plain > y.plain

    @coerce
    def __le__(x, y):
        """x.__le__(y) <==> x<=y"""
        return x.plain <= y.plain

    @coerce
    def __lt__(x, y):
        """x.__lt__(y) <==> x<y"""
        return x.plain < y.plain

    @coerce
    def __ne__(x, y):
        """x.__ne__(y) <==> x!=y"""
        return x.plain != y.plain

    @coerce
    def count(S, sub, *args):
        """S.count(sub[, start[, end]]) -> int

        Return the number of non-overlapping occurrences of substring sub in
        Unicode string S[start:end].  Optional arguments start and end are
        interpreted as in slice notation."""
        return S.plain.count(sub.plain, *args)

    @coerce
    def find(S, sub, *args):
        """S.find(sub [,start [,end]]) -> int

        Return the lowest index in S where substring sub is found,
        such that sub is contained within s[start:end].  Optional
        arguments start and end are interpreted as in slice notation.

        Return -1 on failure."""
        return S.plain.find(sub.plain, *args)

    @coerce
    def rfind(S, sub, *args):
        """S.rfind(sub [,start [,end]]) -> int

        Return the highest index in S where substring sub is found,
        such that sub is contained within s[start:end].  Optional
        arguments start and end are interpreted as in slice notation.

        Return -1 on failure."""
        return S.plain.rfind(sub.plain, *args)

    @coerce
    def index(S, sub, *args):
        """S.index(sub [,start [,end]]) -> int

        Like S.find() but raise ValueError when the substring is not found."""
        return S.plain.index(sub.plain, *args)

    @coerce
    def rindex(S, sub, *args):
        """S.rindex(sub [,start [,end]]) -> int

        Like S.rfind() but raise ValueError when the substring is not found."""
        return S.plain.rindex(sub.plain, *args)

    @coerce
    def partition(S, sep):
        """S.partition(sep) -> (head, sep, tail)

        Searches for the separator sep in S, and returns the part before it,
        the separator itself, and the part after it.  If the separator is not
        found, returns S and two empty strings."""
        try:
            i = S.index(sep)
        except ValueError:
            return S.clone(), S.clone(u''), S.clone(u'')
        j = i + len(sep)
        return S[:i], S[i:j], S[j:]

    @coerce
    def rpartition(S, sep):
        """S.rpartition(sep) -> (tail, sep, head)

        Searches for the separator sep in S, starting at the end of S, and
        returns the part before it, the separator itself, and the part after
        it.  If the separator is not found, returns two empty strings and S."""
        try:
            i = S.rindex(sep)
        except ValueError:
            return S.clone(u''), S.clone(u''), S.clone()
        j = i + len(sep)
        return S[:i], S[i:j], S[j:]

    @coerce
    def split(S, *args):
        """S.split([sep [,maxsplit]]) -> list of strings

        Return a list of the words in S, using sep as the
        delimiter string.  If maxsplit is given, at most maxsplit
        splits are done. If sep is not specified or is None, any
        whitespace string is a separator and empty strings are
        removed from the result."""

        # this function is complicated enough wrt the colormap that
        # we need to implement the split algorithm in python, sadly
        if not args:
            sep, maxsplit = None, None
        elif len(args) == 1:
            sep, maxsplit = args[0], None
        elif len(args) == 2:
            sep, maxsplit = args
        else:
            raise TypeError(
                    'split() takes at most 2 arguments (%d given)' % len(args))

        if sep is None:
            sep_re = re.compile(r'\s+')
        else:
            sep_re = re.compile(re.escape(sep.plain))

        parts = []
        plain, colmap = S.plain, S.colmap
        while plain:
            if maxsplit is not None and len(parts) == maxsplit:
                break
            match = sep_re.search(plain)
            if not match:
                break
            start, stop = match.span()
            parts.append(S.clone(plain[:start], colmap[:start]))
            plain, colmap = plain[stop:], colmap[stop:]
        parts.append(S.clone(plain, colmap))
        if sep is None:
            parts = [part for part in parts if part]
        return parts

    @coerce
    def rsplit(S, *args):
        """S.rsplit([sep [,maxsplit]]) -> list of strings

        Return a list of the words in S, using sep as the
        delimiter string, starting at the end of the string and
        working to the front.  If maxsplit is given, at most maxsplit
        splits are done. If sep is not specified, any whitespace string
        is a separator."""

        # this function is complicated enough wrt the colormap that
        # we need to implement the split algorithm in python, sadly
        # it gets worse with rsplit.. but hey it works.
        if not args:
            sep, maxsplit = None, None
        elif len(args) == 1:
            sep, maxsplit = args[0], None
        elif len(args) == 2:
            sep, maxsplit = args
        else:
            raise TypeError(
                    'split() takes at most 2 arguments (%d given)' % len(args))

        if sep is None:
            sep_re = re.compile(r'\s+')
        else:
            sep_re = re.compile(re.escape(sep.plain))

        parts = []
        plain = ''.join(reversed(S.plain))
        colmap = ''.join(reversed(S.colmap))
        while plain:
            if maxsplit is not None and len(parts) == maxsplit:
                break
            match = sep_re.search(plain)
            if not match:
                break
            start, stop = match.span()
            parts.append(S.clone(''.join(reversed(plain[:start])),
                                 ''.join(reversed(colmap[:start]))))
            plain, colmap = plain[stop:], colmap[stop:]
        parts.append(S.clone(''.join(reversed(plain)),
                             ''.join(reversed(colmap))))
        if sep is None:
            parts = [part for part in parts if part]
        return list(reversed(parts))

    def splitlines(S, keepends=False):
        """S.splitlines([keepends]]) -> list of strings

        Return a list of the lines in S, breaking at line boundaries.
        Line breaks are not included in the resulting list unless keepends
        is given and true."""

        # this function is complicated enough wrt the colormap that
        # we need to implement the split algorithm in python, sadly
        # splitlines is slightly less complicated, thankfully, due to
        # not needing to specify sep or maxsplit and no rsplitlines
        sep_re = re.compile(r'(\r\n|[\r\n])')
        parts = []
        plain, colmap = S.plain, S.colmap
        while plain:
            match = sep_re.search(plain)
            if not match:
                break
            start, stop = match.span()
            line = S.clone(plain[:start], colmap[:start])
            if keepends:
                line += S.clone(plain[start:stop], colmap[start:stop])
            parts.append(line)
            plain, colmap = plain[stop:], colmap[stop:]
        parts.append(S.clone(plain, colmap))
        return parts

    @coerce
    def join(S, sequence):
        """S.join(sequence) -> colstr

        Return a string which is the concatenation of the strings in the
        sequence.  The separator between elements is S."""
        sequence = list(sequence)  # in case it's a generator
        return S.clone(S.plain.join(item.plain for item in sequence),
                       S.colmap.join(item.colmap for item in sequence))

    @coerce
    def strip(S, chars=None):
        """S.strip([chars]) -> colstr

        Return a copy of the string S with leading and trailing
        whitespace removed.
        If chars is given and not None, remove characters in chars instead.
        If chars is a str, it will be converted to colstr before stripping"""
        return S.lstrip(chars).rstrip(chars)

    @coerce
    def lstrip(S, chars=None):
        """S.lstrip([chars]) -> colstr

        Return a copy of the string S with leading whitespace removed.
        If chars is given and not None, remove characters in chars instead.
        If chars is a str, it will be converted to colstr before stripping"""
        orig_size = len(S.plain)
        new = S.clone()
        if isinstance(chars, colstr):
            chars = chars.plain
        new.plain = new.plain.lstrip(chars)
        new.colmap = new.colmap[orig_size - len(new.plain):]
        return new

    @coerce
    def rstrip(S, chars=None):
        """S.rstrip([chars]) -> colstr

        Return a copy of the string S with trailing whitespace removed.
        If chars is given and not None, remove characters in chars instead.
        If chars is a str, it will be converted to colstr before stripping"""
        orig_size = len(S.plain)
        new = S.clone()
        if isinstance(chars, colstr):
            chars = chars.plain
        new.plain = new.plain.rstrip(chars)
        x = (orig_size - len(new.plain)) * -1
        if x < 0:
            new.colmap = new.colmap[:x]
        return new

    def expandtabs(S, tabsize=8):
        """S.expandtabs([tabsize]) -> colstr

        Return a copy of S where all tab characters are expanded using spaces.
        If tabsize is not given, a tab size of 8 characters is assumed."""
        out = []
        for ch in S:
            if ch == '\t':
                ch = S.clone(u' ' * tabsize, ch.colmap * tabsize)
            out.append(ch)
        return S.clone(u'').join(out)

    @coerce
    def center(S, width, fillchar=None):
        """S.center(width[, fillchar]) -> colstr

        Return S centered in a Unicode string of length width. Padding is
        done using the specified fill character (default is a space)"""
        if fillchar is None:
            fillchar = S.clone(u' ', S.reset_char)
        pad = fillchar * int((width - len(S)) / 2)
        out = [pad, S, pad]
        if width % 2:
            out.insert(0, fillchar)
        return S.clone(u'').join(out)

    @coerce
    def ljust(S, width, fillchar=None):
        """S.ljust(width[, fillchar]) -> int

        Return S left justified in a Unicode string of length width. Padding is
        done using the specified fill character (default is a space)."""
        if fillchar is None:
            fillchar = S.clone(u' ', S.reset_char)
        return S + fillchar * (width - len(S))

    @coerce
    def rjust(S, width, fillchar=None):
        """S.rjust(width[, fillchar]) -> colstr

        Return S right justified in a Unicode string of length width. Padding is
        done using the specified fill character (default is a space)."""
        if fillchar is None:
            fillchar = S.clone(u' ', S.reset_char)
        return fillchar * (width - len(S)) + S

    def reverse(S):
        """S.reverse(S) -> colstr"""
        return S.clone('').join(reversed(S))

    @coerce
    def translate(S, table):
        """S.translate(table) -> colstr

        Return a copy of the string S, where all characters have been mapped
        through the given translation table, which must be a mapping of
        Unicode ordinals to Unicode ordinals, Unicode strings or None.
        Unmapped characters are left untouched. Characters mapped to None
        are deleted."""

        # aaaand, this would ALMOST be simple, except the right-hand
        # side of the translate map for unicode objects can replace single
        # characters with multiple ones, which would stretch our colormap
        # in undefined ways.
        new = []
        for ch, col in zip(S.plain, S.colmap):
            o = ord(ch)
            if o in table:
                repl = table[o]
                if repl is None:
                    continue
                elif isinstance(repl, colstr):
                    ch, col = repl.plain, repl.colmap
                elif isinstance(repl, int):
                    ch = unichr(repl)
                else:
                    raise TypeError('character mapping must return integer, '
                                    'None or unicode')
            new.append(S.clone(ch, col))
        return S.clone('').join(new)

    def zfill(S, width):
        """S.zfill(width) -> colstr

        Pad a numeric string S with zeros on the left, to fill a field
        of the specified width. The string S is never truncated."""
        return S.rjust(width, '0')

    @coerce
    def replace(S, old, new, count=None, keepcolor=False):
        """S.replace (old, new[, count]) -> colstr

        Return a copy of S with all occurrences of substring
        old replaced by new.  If the optional argument count is
        given, only the first count occurrences are replaced.

        If keepcolor is True, the replaced bits will keep the same
        colormap as the parts they are replacing, albeit with undefined
        results if new and old are of different lengths.  The default
        (keepcolor=False) will cause the new pieces to have the color of
        the new object."""

        parts = []
        offset = len(old)
        S = S.clone()
        while S:
            if old not in S or count is not None and count == len(parts):
                break
            start = S.index(old)
            stop = start + offset
            if keepcolor:
                new = new.clone(None, S.colmap[start:stop])
            parts.append(S[:start] + new)
            S = S[stop:]
        parts.append(S)
        return S.clone('').join(parts)

    @coerce
    def __mod__(x, y, keepcolor=False):
        """x.__mod__(y) <==> x%y"""

        # i feel sorry for anyone who has to look at this piece of code :D
        # in essence, it cycles through sprintf format strings and
        # applies the replacement values individually.  the purpose of
        # this is to make sure the underly colormap is kept in tact.

        ytype = type(y)
        if ytype not in (dict, tuple):
            y = (y,)
            ytype = tuple
        parts = []
        if ytype is tuple:
            pos = 0
        x = x.clone()
        while x:
            match = x.fmt_re.search(x.plain)
            if not match:
                break
            start, stop = match.span()
            parts.append(x[:start])
            if match.group(5) == '%':
                parts.append('%')
            else:
                fmt = x[start:stop]
                if ytype is tuple:
                    val = y[pos]
                    pos += 1
                else:
                    mapkey = match.group(1)
                    val = y[mapkey]
                if isinstance(val, colstr):
                    plain, colmap = val.plain, val.colmap
                else:
                    plain, colmap = val, ''
                if keepcolor:
                    colmap = fmt.colmap
                if ytype is dict:
                    plain = {mapkey: plain}
                parts.append(x.clone(fmt.plain % plain, colmap))
            x = x[stop:]
        parts.append(x)
        return x.clone('').join(parts)

    def __rmod__(x, y):
        """x.__rmod__(y) <==> y%x"""
        # could be useful somewhere
        return y % len(x)

    def format(self, *args, **kwargs):
        """S.format(*args, **kwargs) -> colstr"""
        raise NotImplementedError


# transform rainbow colormap into compiled version
BRUSH_MAP = dict((name, colstr.compile(map))
                 for name, map in BRUSH_MAP.iteritems())


class CowScriptError(Exception):

    """Base CowScript exception class"""

    def __init__(self, msg=''):
        super(CowScriptError, self).__init__()
        self.msg = msg

    def __str__(self):
        return str(self.msg)

    @property
    def name(self):
        return type(self).__name__


class ParseError(CowScriptError):

    """An error encountered parsing cowscript"""

    def __init__(self, msg='', ch='', pos=0, state=None):
        super(ParseError, self).__init__(msg)
        self.ch = ch
        self.pos = pos
        self.state = state

    def __str__(self):
        return '%s on %r at %d: %s [%s]' % (
                self.name, self.ch, self.pos, self.msg, self.state)


class TokenizeError(ParseError):

    """Exception class for token parsing errors"""


class InsubError(CowScriptError):

    """Exception class for Insub"""


class CowScript(object):

    """Example of a complex expression:

    $(cow_dir=/home/cjones/.irssi/cows)
    $(figlet_dir=/usr/local/share/figlet)
    [
        ["hi" | paint | figlet | mirror]
        +["there" | paint(usa) | banner(25,fg=#,bg=.) | rotate | mirror]
        ["friend" | figlet(crawford) | paint | outline(box)]
    ] | cow(wtf) | paint(canada)"""

    # tokens
    TOKEN_SETTING = 'SET'
    TOKEN_PUSH = 'PUSH'
    TOKEN_POP = 'POP'
    TOKEN_DATA = 'DATA'
    TOKEN_FILTER = 'FILTER'
    TOKEN_ARGS = 'ARGS'
    TOKEN_POP_APPEND = 'APPEND'
    TOKEN_POP_NEWLINE = 'NEWLINE'

    # states
    STATE_NONE = 'No state'
    STATE_SET_WAIT = 'Waiting for global set block'
    STATE_SET_READING = 'Reading global setting'
    STATE_DATA_READING = 'Reading text data'
    STATE_FILTER_WAIT = 'Waiting for filter name'
    STATE_FILTERNAME_READING = 'Reading filter name'
    STATE_NESTED_WAIT = 'Waiting for nest block after append'
    STATE_ARGS_READING = 'Reading filter args'

    # character classes
    CHARS_WHITESPACE = (' ', '\t', '\r', '\n')
    CHARS_FILTERNAME = [chr(o) for o in (range(97, 123) + range(65, 91) +
                                         range(48, 58) + range(95, 96))]

    # strings
    STR_SET_START = '$'
    STR_SET_BLOCK_START = '('
    STR_SET_BLOCK_END = ')'
    STR_ESCAPE = '\\'
    STR_NEST_START = '['
    STR_NEST_END = ']'
    STR_DATA_START = '"'
    STR_DATA_END = '"'
    STR_PIPE = '|'
    STR_APPEND = '+'
    STR_ARGS_START = '('
    STR_ARGS_END = ')'

    def __init__(self, cmd):
        super(CowScript, self).__init__()
        self.tokens = self.tokenize(cmd)

    @classmethod
    def tokenize(cls, string):
        """Tokenize a command expression"""

        pos = 0
        state = cls.STATE_NONE
        store = None
        readto = None
        buf = []
        level = 0
        append = set()
        tokens = []

        def unexpected(ch):
            raise TokenizeError('unexpected char', ch, pos, state)

        while True:
            if pos >= len(string):
                if readto is not None:
                    ch = readto
                else:
                    break
            else:
                ch = string[pos]

            if readto:
                if readto is not None:
                    callback = hasattr(readto, '__call__')
                    if callback:
                        done = readto(ch)
                    else:
                        done = (ch == readto and
                                string[pos - 1] != cls.STR_ESCAPE)

                if done:
                    data = ''.join(buf)
                    if state == cls.STATE_SET_READING:
                        tokens.append((cls.TOKEN_SETTING, data))
                    elif state == cls.STATE_DATA_READING:
                        tokens.append((cls.TOKEN_DATA, data))
                    elif state == cls.STATE_FILTERNAME_READING:
                        tokens.append((cls.TOKEN_FILTER, data))
                    elif state == cls.STATE_ARGS_READING:
                        tokens.insert(-1, (cls.TOKEN_ARGS, data))

                    readto = None
                    buf = []
                    state = cls.STATE_NONE

                    if callback:
                        continue

                else:
                    buf.append(ch)

            elif state == cls.STATE_NONE:
                if ch in cls.CHARS_WHITESPACE:
                    pass
                elif ch == cls.STR_SET_START:
                    state = cls.STATE_SET_WAIT
                elif ch == cls.STR_NEST_START:
                    level += 1
                    tokens.append((cls.TOKEN_PUSH, ''))
                elif ch == cls.STR_NEST_END:
                    if level in append:
                        val = cls.TOKEN_POP_APPEND
                        append.remove(level)
                    else:
                        val = cls.TOKEN_POP_NEWLINE
                    tokens.append((cls.TOKEN_POP, val))
                    level -= 1
                elif ch == cls.STR_DATA_START:
                    state = cls.STATE_DATA_READING
                    readto = cls.STR_DATA_END
                elif ch == cls.STR_PIPE:
                    state = cls.STATE_FILTER_WAIT
                elif ch == cls.STR_APPEND:
                    append.add(level + 1)
                    state = cls.STATE_NESTED_WAIT
                elif ch == cls.STR_ARGS_START:
                    state = cls.STATE_ARGS_READING
                    readto = cls.STR_ARGS_END
                else:
                    unexpected(ch)

            elif state == cls.STATE_SET_WAIT:
                if ch == cls.STR_SET_BLOCK_START:
                    state = cls.STATE_SET_READING
                    readto = cls.STR_SET_BLOCK_END
                elif ch in cls.CHARS_WHITESPACE:
                    pass
                else:
                    unexpected(ch)

            elif state == cls.STATE_FILTER_WAIT:
                if ch in cls.CHARS_WHITESPACE:
                    pass
                elif ch in cls.CHARS_FILTERNAME:
                    state = cls.STATE_FILTERNAME_READING
                    readto = lambda ch: ch not in cls.CHARS_FILTERNAME
                    continue
                else:
                    raise TokenizeError('invalid filter char', ch, pos, state)

            elif state == cls.STATE_NESTED_WAIT:
                if ch in cls.CHARS_WHITESPACE:
                    pass
                elif ch == cls.STR_NEST_START:
                    state = cls.STATE_NONE
                    continue
                else:
                    raise TokenizeError(
                            'appending to non-nested block', ch, pos, state)

            pos += 1

        if level:
            raise TokenizeError('missing end of nested block', ch, pos, state)
        if state != cls.STATE_NONE:
            raise TokenizeError('invalid end state', ch, pos, state)

        return tokens


class filter(object):

    """Decorator for registering a function as a filter"""

    filters = []
    aliases = []

    def __init__(self, *types):
        self.types = types

    def __call__(self, func):
        code = func.func_code
        keys = code.co_varnames[2:code.co_argcount]
        self.__class__.filters.append((func, keys))

        def inner(obj, lines, *args, **kwargs):
            args = list(args)
            for key in keys[len(args):]:
                if key in kwargs:
                    val = kwargs[key]
                else:
                    val = getattr(obj, '%s_%s' % (func.__name__, key))
                args.append(val)
            fixed = []
            for arg, argtype in zip(args, self.types):
                if arg is not None and type(arg) is not argtype:
                    if argtype is bool:
                        arg = arg.lower() not in ('0', 'no', 'false', 'off')
                    else:
                        arg = argtype(arg)
                fixed.append(arg)
            return func(obj, lines, *fixed)

        inner.__name__ = func.__name__
        inner.__doc__ = func.__doc__
        inner.isfilter = True
        return inner

    def __get__(self, obj, cls):
        """Descriptor method to generate help"""
        return '%%prog [options] [expr]\n\n%s\n\nFilters:\n\n%s' % (
                CowScript.__doc__,
                '\n'.join('    %s%s - %s' % (
                              func.__name__,
                              '(%s)' % ', '.join(args) if args else '',
                              func.__doc__)
                          for func, args in self.__class__.filters))


def alias(func, *args, **kwargs):

    """Create a filter alias"""

    def inner(self, lines):
        return func(self, lines, *args, **kwargs)

    inner.__name__ = func.__name__
    inner.__doc__ = func.__doc__
    inner.isfilter = True
    return inner


class Insub(object):

    """Suite of text filters to annoy people on IRC"""

    def __init__(self, expr, **kwargs):
        self.__dict__.update(DEFAULTS, **kwargs)
        cow = CowScript(expr)
        self.tokens = cow.tokens

    def render(self):
        """Render data using the provided filters"""
        stack = []
        lines = []
        args = None
        for token, val in self.tokens:
            if token == CowScript.TOKEN_PUSH:
                stack.append(lines)
                lines = []
            elif token == CowScript.TOKEN_SETTING:
                key, val = val.split('=', 1)
                setattr(self, key, val)
            elif token == CowScript.TOKEN_DATA:
                lines.append(colstr(val))
            elif token == CowScript.TOKEN_FILTER:

                funcs = [getattr(self, key) for key in dir(self)
                         if key.startswith(val)]
                funcs = [func for func in funcs
                         if hasattr(func, 'isfilter') and func.isfilter]

                if len(funcs) > 1:
                    matches = ', '.join(func.__name__ for func in funcs)
                    error = 'ambiguous filter: %s (%s)' % (val, matches)
                    raise InsubError(error)

                filter = funcs.pop()

                if args:
                    kwargs = {}
                    new = []
                    for arg in re.split(r'\s*,\s*', args):
                        if '=' in arg:
                            k, v = arg.split('=', 1)
                            kwargs[str(k)] = v
                        else:
                            new.append(arg)
                    args = tuple(new)
                else:
                    args = ()
                    kwargs = {}
                lines = list(filter(lines, *args, **kwargs))
                args = None

            elif token == CowScript.TOKEN_POP:
                # XXX if val is APPEND we need something fancier
                lines += stack.pop(0)
            elif token == CowScript.TOKEN_ARGS:
                args = val

        for line in lines:
            yield line

    @filter()
    def version(self, lines):
        """Display our version"""
        for line in lines:
            yield line
        yield colstr('%s %s' % (self.name, __version__))

    @filter(unicode, bool, float)
    def execute(self, lines, cmd, pty, timeout):
        """Execute cmd and add data to the output"""
        for line in lines:
            yield line

        args = shlex.split(cmd)
        if pty:
            pid, fd = ptyfork()
        else:
            fd, writer = os.pipe()
            pid = os.fork()
            if not pid:
                os.close(fd)
                os.dup2(writer, sys.stdout.fileno())
                os.dup2(writer, sys.stderr.fileno())
            os.close(writer)

        if not pid:
            os.execvp(args[0], args)
            sys.exit(1)

        buf = []
        while True:
            data = None
            if fd in select([fd], [], [], timeout)[0]:
                try:
                    data = os.read(fd, 1024)
                except OSError, error:
                    if error.errno != errno.EIO:
                        raise
            if not data:
                yield colstr(''.join(buf).decode(self.input_encoding))
                break
            buf.append(data)
            if '\n' in data:
                lines = ''.join(buf).splitlines()
                buf = [lines.pop()]
                for line in lines:
                    yield colstr(line.decode(self.input_encoding))

        os.close(fd)
        os.waitpid(pid, 0)

    @filter(unicode)
    def read(self, lines, path):
        """Read from file and add data to output"""
        for line in lines:
            yield line
        with open(path, 'r') as fp:
            for line in fp:
                yield colstr(line.rstrip().decode(self.input_encoding))

    @filter(int)
    def spook(self, lines, words):
        """Get NSA's attention"""
        for line in lines:
            yield line
        yield colstr(' ').join(random.sample(SPOOK_PHRASES, words))

    @filter()
    def jive(self, lines):
        """Make speech more funky"""
        raise NotImplementedError('needs colstr() implementation')
        for line in lines:
            for search, replace in JIVE_RULES:
                line = search.sub(replace, line)
            yield line

    @filter()
    def chef(self, lines):
        """Make speech more swedish"""
        raise NotImplementedError('needs colstr() implementation')
        for line in lines:
            new = []
            for word in line.split():
                for pat, repl in BORK_RULES:
                    if pat.search(word):
                        word = pat.sub(repl, word)
                        break
                new.append(word)
            yield ' '.join(new)

    bork = alias(chef)

    @filter()
    def scramble(self, lines):
        """Scramble inner letters of a word"""
        for line in lines:
            new = []
            for word in line.split():
                if len(word) > 3:
                    word = list(word)
                    first = word.pop(0)
                    last = word.pop()
                    random.shuffle(word)
                    word = first + colstr().join(word) + last
                new.append(word)
            yield colstr(' ').join(new)

    shuffle = alias(scramble)

    @filter()
    def leet(self, lines):
        """Make text into leet-speak"""
        for line in lines:
            new = []
            for ch in line:
                if ch.plain in LEET_MAP:
                    ch = ch.clone(random.choice(LEET_MAP[ch.plain]), ch.colmap)
                new.append(ch)
            yield colstr().join(new)

    @filter(int, unicode, unicode)
    def dongs(self, lines, freq, left, right):
        """Add dongs"""
        points = {}
        for i, line in enumerate(lines):
            for j, ch in enumerate(line):
                if ch != ' ':
                    points.setdefault(i, []).append(j)
        choices = []
        for i, js in points.iteritems():
            x, y = min(js), max(js)
            if x >= len(left):
                choices.append((i, x - len(left), left))
            choices.append((i, y, right))
        if freq > len(choices):
            freq = len(choices)
        dongs = random.sample(choices, freq)
        for i, j, str in dongs:
            line = list(lines[i])
            for x in xrange(len(str)):
                y = x + j
                if y == len(line):
                    line.append(' ')
                line[x + j] = str[x]
            lines[i] = colstr().join(line)
        return lines

    @filter()
    def uniflip(self, lines):
        """Reverse text using unicode flippage"""
        for line in lines:
            yield line.translate(UNIFLIP)

    @filter()
    def unibig(self, lines):
        """Change ASCII chars to REALLY BIG unichars"""
        for line in lines:
            yield line.translate(UNIBIG)

    @filter()
    def asciiflip(self, lines):
        """Reverse text using ascii flippage"""
        for line in lines:
            yield line.translate(ASCIIFLIP)

    @filter()
    def mirror(self, lines):
        """Mirror image text"""
        size = max(len(line) for line in lines)
        for line in lines:
            yield line.translate(MIRROR_MAP).reverse().rjust(size)

    @filter()
    def jigs(self, lines):
        """Shift right-hand homerow to the right"""
        for line in lines:
            yield line.translate(JIGS_MAP)

    @filter(float, int, unicode)
    def sine(self, lines, freq, height, bg):
        """Arrange text in a sine wave pattern"""
        out = defaultdict(colstr)
        line_num = 0
        for line in lines:
            width = len(line) * freq
            plot = {}
            x = 0
            for ch in line:
                y = int(height * math.sin(x)) + height
                plot.setdefault('%.2f' % x, {})[y] = ch
                x += freq
            for y in xrange(height * 2 + 1):
                x = 0
                while x <= width:
                    xrep = '%.2f' % x
                    if xrep in plot and y in plot[xrep]:
                        out[line_num] += plot[xrep][y]
                    else:
                        out[line_num] += bg
                    x += freq
                line_num += 1
        lines = [item[1] for item in sorted(out.iteritems())]
        empty = bg * max(len(line) for line in lines)
        for line in lines:
            if line != empty:
                yield line

    wave = alias(sine)

    @filter()
    def diagonal(self, lines):
        """Arrange text diagonally"""
        for line in lines:
            for i, ch in enumerate(line):
                yield colstr(' ') * i + ch

    @filter()
    def slope(self, lines):
        """Arrange text on a slope"""
        for line in lines:
            spacer = 0
            for word in line.split():
                yield colstr(' ') * spacer + word
                spacer += len(word)

    @filter(int, int)
    def matrix(self, lines, size, spacing):
        """Arrange text in a matrix"""
        data = colstr(' ').join(lines)
        out = defaultdict(colstr)
        for i in xrange(0, len(data), size):
            chunk = data[i:i + size]
            for j in xrange(len(chunk)):
                out[j] += chunk[j] + colstr(' ') * spacing
        for i, line in sorted(out.iteritems()):
            yield line

    @filter(unicode, unicode, unicode, unicode, bool, bool)
    def figlet(self, lines, font, dir, direction, justify, reverse, flip):
        figlet = Figlet(prefix=dir, font=font, direction=direction,
                        justify=justify)
        lines = figlet.render(colstr(' ').join(lines))
        if reverse:
            lines = [line.translate(FIG_REV_MAP).reverse() for line in lines]
        if flip:
            lines = [line.translate(FIG_FLIP_MAP) for line in reversed(lines)]
        return lines

    @filter(int, unicode, unicode)
    def banner(self, lines, width, fg, bg):
        """Convert text to banner text"""
        output = []
        newline = colstr(bg) * 132
        for ch in colstr(' ').join(lines):
            if ch.plain in BANNER_RULES:
                line = list(newline)
                i = 0
                while i < len(BANNER_RULES[ch.plain]):
                    x = BANNER_RULES[ch.plain][i]
                    if x >= 128:
                        output += [colstr().join(line)] * (x & 63)
                        line = list(newline)
                        i += 1
                    else:
                        n = BANNER_RULES[ch.plain][i + 1]
                        line[x:x + n] = ch.clone(fg) * n
                        i += 2

        # scale font to width
        scale = int(132 / width)
        for i, line in enumerate(output):
            if not i % scale:
                scaled = []
                for j, ch in enumerate(line):
                    if not j % scale:
                        scaled.append(ch)
                yield colstr().join(scaled)

    @filter(int, unicode)
    def hug(self, lines, size, arms):
        """Add hugs around the text"""
        size = max(len(line) for line in lines)
        left = colstr(arms[0]) * size
        right = colstr(arms[1]) * size
        for line in lines:
            yield colstr('%s %s %s') % (left, line.center(size), right)

    @filter(bool)
    def rotate(self, lines, cw):
        """Rotate text 90 degrees"""
        m={45: 124,
                47: 92,
                51: 119,
                60: 94,
                62: 118,
                66: 109,
                92: 47,
                94: 62,
                109: 51,
                118: 60,
                119: 66,
                124: 45, 95:124, 40:45, 41:45} #XXX need a func
        size = max(len(line) for line in lines)
        lines = [line.ljust(size) for line in reversed(lines)]
        rotated = []
        for i in xrange(size):
            rotated_line = []
            for line in lines:
                rotated_line.append(line[i])
            if cw:
                rotated_line = reversed(rotated_line)
            rotated.append(colstr().join(rotated_line))
        if cw:
            rotated= reversed(rotated)
        for line in rotated:
            yield line.translate(m)

    @filter(int)
    def wrap(self, lines, width):
        """Wrap text"""
        raise NotImplementedError('needs colstr() implementation')
        for line in textwrap.wrap(' '.join(lines), width=self.wrap_width):
            yield line

    @filter()
    def chalkboard(self, lines):
        """Put text onto bart's chalkboard"""
        data = (colstr(' ').join(lines) + colstr(' ')).upper().replace('*', '')
        i = 0
        output = colstr(CHALKBOARD)
        while output.count('*'):
            output = output.replace('*', data[i], 1)
            i += 1
            if i == len(data):
                i = 0
        for line in output.splitlines():
            yield line

    bart = alias(chalkboard)

    @filter(unicode)
    def fill(self, lines, char):
        """Filll all blank lines with provided background char"""
        size = max(len(line) for line in lines)
        lines = [line.ljust(size) for line in lines]
        for line in lines:
            yield line.replace(' ', char)

    @filter(unicode, unicode, unicode, unicode, unicode)
    def cow(self, lines, file, dir, style, eyes, tongue):
        """Make a cow say it"""

        # look for the cow to use
        template = DEFAULT_COW
        if dir:
            if not file.endswith('.cow'):
                file += '.cow'
            path = os.path.join(dir, file)
            if os.path.basename(path) != 'default.cow' and os.path.exists(path):
                with open(path, 'r') as fp:
                    template = fp.read()

        # extract the actual cow from perl garbage
        cow = []
        in_cow = False
        for line in template.splitlines():
            if 'EOC' in line:
                in_cow = not in_cow
            elif in_cow:
                cow.append(line)
        cow = u'\n'.join(cow)

        # perform substitions on cow
        if style == 'say':
            thoughts = '\\'
        elif style == 'think':
            thoughts = 'o'
        cow = re.sub(r'\\(.)', r'\1', cow)

        # make it a COLOR-AWARE COW before constructing the thought bubble.
        # this allows all kinds of great things, like.. making the tongue red.
        cow = colstr(cow)

        cow = cow.replace('$thoughts', thoughts)
        cow = cow.replace('$eyes', eyes)
        cow = cow.replace('$tongue', tongue)

        # construct the thought bubble
        lines = list(lines)
        size = max(len(line) for line in lines)
        yield colstr(' %s ' % ('_' * (size + 2)))
        for i, line in enumerate(lines):
            if style == 'think':
                left, right = '(', ')'
            elif len(lines) == 1:
                left, right = '<', '>'
            else:
                if i == 0:
                    left, right = '/', '\\'
                elif i == len(lines) - 1:
                    left, right = '\\', '/'
                else:
                    left = right = '|'
            yield colstr('%s %s %s') % (left, line.ljust(size), right)
        yield colstr(' %s ' % ('-' * (size + 2)))

        # yield the cow
        for line in cow.splitlines():
            yield line

    @filter()
    def flip(self, lines):
        """Flip over lines"""
        lines = list(lines)
        for line in reversed(lines):
            yield line

    @filter(unicode)
    def outline(self, lines, style):
        """Draw an outline around text"""
        lines = list(lines)
        size = max(len(line) for line in lines)

        # top part
        if style == 'arrow':
            yield colstr('\\' + 'v' * (size + 2) + '/')
            left, right = '>', '<'
            bottom = colstr('/' + '^' * (size + 2) + '\\')
        elif style == 'box':
            yield colstr('+' + '-' * (size + 2) + '+')
            left = right = '|'
            bottom = colstr('+' + '-' * (size + 2) + '+')
        elif style == '3d':
            yield colstr('  ' + '_' * (size + 3))
            yield colstr(' /' + ' ' * (size + 2) + '/|')
            yield colstr('+' + '-' * (size + 2) + '+ |')
            left, right = '|', '| |'
            bottom = colstr('+' + '-' * (size + 2) + '+/')

        for line in lines:
            yield colstr('%s %s%s %s') % (
                    left, line, ' ' * (size - len(line)), right)
        yield bottom

    box = alias(outline, 'box')
    arrow = alias(outline, 'arrow')

    @filter(unicode)
    def prefix(self, lines, string):
        """Prepend text to each line"""
        for line in lines:
            yield colstr(string) + line

    @filter(unicode)
    def postfix(self, lines, string):
        """Append text to each line"""
        for line in lines:
            yield line + string

    @filter()
    def strip(self, lines):
        """Remove empty lines and excess whitespace"""
        lines = [line for line in lines if not blank_re.search(line.plain)]
        smallest = None
        for line in lines:
            try:
                lead = lead_re.search(line.plain).group(1)
            except AttributeError:
                continue
            lead = len(lead)
            if smallest is None:
                smallest = lead
            elif lead < smallest:
                smallest = lead
        if smallest:
            lines = [line[smallest - 1:] for line in lines]
        for line in lines:
            yield line.rstrip()

    wsor_re = re.compile(r'(\s+)|\S+')

    @filter(unicode)
    def strike(self, lines, char):
        """Replace all non-whitespace with character"""
        for line in lines:
            new = []
            i = 0
            while i < len(line):
                match = self.wsor_re.match(line.plain, i)
                if not match:
                    break
                x, y = match.span()
                part = line[x:y]
                if not match.group(1):
                    part.plain = char * (y - x)
                new.append(part)
                i = y
            yield colstr().join(new)

    @filter(unicode)
    def negative(self, lines, char):
        """Make a negative with the given char"""
        size = max(len(line) for line in lines)
        lines = [line.ljust(size) for line in lines]
        for line in lines:
            new = []
            i = 0
            while i < len(line):
                match = self.wsor_re.match(line.plain, i)
                if not match:
                    break
                x, y = match.span()
                part = line[x:y]
                if match.group(1):
                    part.plain = char * (y - x)
                else:
                    part.plain = ' ' * (y - x)
                new.append(part)
                i = y
            yield colstr().join(new)

    @filter()
    def nocolor(self, lines):
        """Mark text in buffer as uncolorable"""
        for line in lines:
            yield line.clone(None, line.nocolor_char * len(line))

    @filter(unicode, int, int)
    def paint(self, lines, brush, offset, skew):
        """Make stuff pretty"""
        map = BRUSH_MAP[brush]
        for line in lines:
            new = []
            for i, ch in enumerate(line):
                if ch.colmap == ch.reset_char:
                    ch.colmap = map[(offset + i) % len(map)]
                new.append(ch)
            offset += skew
            yield colstr().join(new)
        self.paint_offset = offset % 256

    # create aliases for the different brushmaps
    for key in BRUSH_MAP:
        locals()[key] = alias(paint, key)

    @property
    def name(self):
        """Name of the script"""
        return os.path.basename(sys.argv[0])

    def __iter__(self):
        """Iterate over rendered data"""
        for line in self.render():
            yield line

    usage = filter()


def main():
    """CLI-based interface"""
    optparse = OptionParser(version=__version__, usage=Insub.usage)
    optparse.add_option('-i', dest='input_encoding', metavar='<encoding>',
                        default=INPUT_ENCODING,
                        help='input encoding (%default)')
    optparse.add_option('-o', dest='output_encoding', metavar='<encoding>',
                        default=OUTPUT_ENCODING,
                        help='output encoding (%default)')
    optparse.add_option('-s', dest='scheme', metavar='<scheme>',
                        default=SCHEME, help='color scheme (%default)')
    optparse.add_option('-c', dest='cow_dir', metavar='<cow dir>',
                        default=DEFAULTS['cow_dir'],
                        help='location of .cow files (default: %default)')
    optparse.add_option('-f', dest='figlet_dir', metavar='<figlet dir>',
                        default=DEFAULTS['figlet_dir'],
                        help='location of figlet fonts (default: %default)')
    optparse.add_option('-p', dest='paint_offset', metavar='<#>', type='int',
                        default=DEFAULTS['paint_offset'],
                        help='initial rainbow offset (default: %default)')
    opts, args = optparse.parse_args()

    #expr = '"test"|cow|dongs'
    expr = ' '.join(args) if args else sys.stdin.read()
    expr = expr.decode(opts.input_encoding)
    lines = Insub(expr, **opts.__dict__)
    data = colstr('\n').join(lines)
    data = data.render(opts.scheme)
    print data.encode(opts.output_encoding)

    return 0


if __name__ == '__main__':
    sys.exit(main())
END_OF_INSUB_SCRIPT

init_onload($data);
