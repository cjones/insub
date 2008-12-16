#!/usr/bin/env python

from __future__ import with_statement
import sys
import os
import re
from optparse import OptionParser

__version__ = '0.5'
__author__ = 'cj_ <cjones@gruntle.org>'

class FigletFont(object):

    """
    This class represents the currently loaded font, including
    meta-data about how it should be displayed by default
    """

    magic_number_re = re.compile(r'^flf2.')
    end_marker_re = re.compile(r'(.)\s*$')

    def __init__(self, prefix=u'.', font=u'standard'):
        self.prefix = prefix
        self.font = font
        self.chars = {}
        self.width = {}
        self.data = None

        font_path = '%s/%s.flf' % (self.prefix, self.font)
        if not os.path.exists(font_path):
            raise Exception("%s doesn't exist" % font_path)
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
                    line = end.sub(u'', line)
                    if len(line) > width:
                        width = len(line)
                    chars.append(line)
                if chars:
                    self.chars[i] = chars
                    self.width[i] = width

        except Exception, error:
            raise Exception('parse error: %s' % error)


class FigletString(str):

    """Rendered figlet font"""

    REV_MAP = ('\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f'
               '\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e'
               '\x1f !"#$%&\')(*+,-.\\0123456789:;>=<?@ABCDEFGHIJKLMNOPQRSTUV'
               'WXYZ]/[^_`abcdefghijklmnopqrstuvwxyz}|{~\x7f\x80\x81\x82\x83'
               '\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91\x92'
               '\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0\xa1'
               '\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0'
               '\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf'
               '\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce'
               '\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd'
               '\xde\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec'
               '\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb'
               '\xfc\xfd\xfe\xff')

    FLIP_MAP = ('\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r\x0e\x0f'
                '\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e'
                '\x1f !"#$%&\'()*+,-.\\0123456789:;<=>?@VBCDEFGHIJKLWNObQbSTU'
                'AMXYZ[/]v-`aPcdefghijklwnopqrstu^mxyz{|}~\x7f\x80\x81\x82'
                '\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91'
                '\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0'
                '\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf'
                '\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe'
                '\xbf\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd'
                '\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc'
                '\xdd\xde\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb'
                '\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa'
                '\xfb\xfc\xfd\xfe\xff')

    def reverse(self):
        return self.new(''.join(reversed(line))
                        for line in self.translate(self.REV_MAP).splitlines())

    def flip(self):
        return self.new(row.translate(self.FLIP_MAP)
                        for row in reversed(self.splitlines()))

    def new(self, seq):
        return FigletString('\n'.join(seq) + '\n')


class FigletRenderingEngine(object):

    """
    This class handles the rendering of a FigletFont,
    including smushing/kerning/justification/direction
    """

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
            return left if self.base.direction == u'right-to-left' else right

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
            if left == '_' and right in r'|/\[]{}()<>':
                return right
            if right == '_' and left  in r'|/\[]{}()<>':
                return left

        if self.base.Font.smush_mode & self.SM_HIERARCHY:
            if left == '|' and right in r'|/\[]{}()<>':
                return right
            if right == '|' and left  in r'|/\[]{}()<>':
                return left
            if left in r'\/' and right in '[]{}()<>':
                return right
            if right in r'\/' and left  in '[]{}()<>':
                return left
            if left in '[]' and right in '{}()<>':
                return right
            if right in '[]' and left  in '{}()<>':
                return left
            if left in '{}' and right in '()<>':
                return right
            if right in '{}' and left  in '()<>':
                return left
            if left in '()' and right in '<>':
                return right
            if right in '()' and left  in '<>':
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
        for c in map(ord, text):
            if c not in self.base.Font.chars:
                continue
            cur_char = self.base.Font.chars[c]
            self.cur_width = self.base.Font.width[c]
            if not len(buf):
                buf = ['' for i in xrange(self.base.Font.height)]
            max_smush = self.smush_amount(buf=buf, cur_char=cur_char)

            # add a character to the buf and do smushing/kerning
            for row in xrange(self.base.Font.height):
                add_left = buf[row]
                add_right = cur_char[row]
                if self.base.direction == u'right-to-left':
                    add_left, add_right = add_right, add_left
                for i in xrange(max_smush):
                    try:
                        left = add_left[len(add_left) - max_smush + i]
                    except:
                        left = ''
                    right = add_right[i]
                    smushed = self.smush_chars(left, right)
                    try:
                        l = list(add_left)
                        l[len(l) - max_smush + i] = smushed
                        add_left = ''.join(l)
                    except:
                        pass
                buf[row] = add_left + add_right[max_smush:]
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

        # return rendered ASCII with hardblanks replaced
        buf = '\n'.join(buf) + '\n'
        buf = buf.replace(self.base.Font.hard_blank, ' ')
        return FigletString(buf)


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


def main():
    prefix = os.path.abspath(os.path.dirname(sys.argv[0]))
    parser = OptionParser(version=__version__, usage='%prog [options] text..')
    parser.add_option('-f', '--font', default='standard',
                      help='font to render with (default: %default)',
                      metavar='FONT')
    parser.add_option('-d', '--fontdir', default=None,
                      help='location of font files', metavar='DIR')
    parser.add_option('-D', '--direction', type='choice',
                      choices=('auto', 'left-to-right', 'right-to-left'),
                      default='auto', metavar='DIRECTION',
                      help='set direction text will be formatted in (default:'
                      ' %default)')
    parser.add_option('-j', '--justify', type='choice',
                      choices=('auto', 'left', 'center', 'right'),
                      default='auto', metavar='SIDE',
                      help='set justification, defaults to print direction')
    parser.add_option('-w', '--width', type='int', default=80, metavar='COLS',
                      help='set terminal width for wrapping/justification (de'
                      'fault: %default)')
    parser.add_option('-r', '--reverse', action='store_true', default=False,
                      help='shows mirror image of output text')
    parser.add_option('-F', '--flip', action='store_true', default=False,
                      help='flips rendered output text over')
    opts, args = parser.parse_args()

    if not args:
        parser.print_help()
        return 1

    figlet = Figlet(prefix=opts.fontdir, font=opts.font,
                    direction=opts.direction, justify=opts.justify,
                    width=opts.width)

    response = figlet.render(' '.join(args))
    if opts.reverse:
        response = response.reverse()
    if opts.flip:
        response = response.flip()
    print response
    return 0


if __name__ == u'__main__':
    sys.exit(main())
