#!/usr/bin/env python

import sys
import re

class ColorError(Exception):

    pass


class Color(object):

    """Library for managing text with ANSI/mIRC color codes"""

    # how to encode this data bitwisey... might require a rewrite at this
    # point to do this shit.. BLARGH.
    #
    # at least i've made progress in understanding the problem at this level
    # major argh-face.
    #
    # default, bg, fg = col >> 7, (col & 112) >> 4, col & 15
    # col = (default << 7) + (bg << 4) + fg

    # colors = ['black',    # 0
    #           'white',    # 1
    #           'red',      # 2
    #           'yellow',   # 3
    #           'green',    # 4
    #           'cyan',     # 5
    #           'blue',     # 6
    #           'magenta']  # 7

    # these contain the rules for parsing out ansi/mirc codes.  a mapping
    # is created to an intensity/0-7 code that both mirc and ansi can share
    # ansi's index is created by using code-30 (+8 if intensity on) while
    # mirc uses its actual 0-15 number code.  note that for background colors,
    # using ones which mean "intensity on" for foreground colors is invalid

    styles = {'mirc': {'color': re.compile('(\x03[0-9,]+\x16*|\x0f)'),
                       'parse': re.compile('\x03([0-9]+)(?:,([0-9]+))?'),
                       'map': [(1, 1), (0, 0), (0, 6), (0, 4), (1, 2), (0, 2),
                               (0, 7), (0, 3), (1, 3), (1, 4), (0, 5), (1, 5),
                               (1, 6), (1, 7), (1, 0), (0, 1)]},
              'ansi': {'color': re.compile('(\x1b\[[0-9;]+m)'),
                       'parse': re.compile('\x1b\[([0-9;]+)'),
                       'map': [(0, 0), (0, 2), (0, 4), (0, 3), (0, 6), (0, 7),
                               (0, 5), (0, 1), (1, 0), (1, 2), (1, 4), (1, 3),
                               (1, 6), (1, 7), (1, 5), (1, 1)]}}

    def __init__(self, style='mirc'):
        if style not in self.styles:
            raise ColorError('style must be one of:', ', '.join(self.styles))
        self.style = style

    def decode(self, data):
        """Decodes text into a stripped version and a normalized colormap"""
        if isinstance(data, basestring):
            data = data.splitlines()
        clean = []
        colmap = []
        for line in data:
            clean_line = []
            colmap_line = []
            current_fg = current_bg = -1
            intense = False
            for item in self.color_re.split(line):
                if not item:
                    continue
                if self.color_re.match(item):
                    if item == '\x0f':
                        current_fg = current_bg = -1
                    else:
                        item = self.parse_re.search(item).groups()
                        if self.style == 'mirc':
                            fg, bg = item
                            if fg:
                                fg = self.map[int(fg)]
                            else:
                                fg = current_fg
                            if bg:
                                bg = self.map[int(bg)]
                            else:
                                bg = current_bg
                            current_fg, current_bg = fg, bg
                        elif self.style == 'ansi':
                            for cmd in map(int, item[0].split(';')):
                                if cmd == 0:
                                    fg = bg = -1
                                    intense = False
                                elif cmd == 1:
                                    intense = True
                                elif cmd in (2, 22):
                                    intense = False
                                elif cmd == 39:
                                    fg = -1
                                elif cmd == 49:
                                    bg = -1
                                elif ((cmd >= 30 and cmd <= 37) or
                                      (cmd >= 40 and cmd <= 47)):
                                    cmd -= 30
                                    if cmd >= 10:
                                        key = 'bg'
                                        cmd -= 10
                                    else:
                                        key = 'fg'
                                    if intense and key == 'fg':
                                        cmd += 8
                                    cmd = self.map[cmd]
                                    if key == 'bg':
                                        current_bg = cmd
                                    else:
                                        current_fg = cmd
                else:
                    clean_line.append(item)
                    colmap_line += [(current_fg, current_bg)] * len(item)
            clean.append(''.join(clean_line))
            colmap.append(colmap_line)
        return clean, colmap

    def encode(self, data, colmap=None):
        """Encode data using the supplied codemap to produce color output"""
        if colmap is None:
            colmap = []
        if isinstance(data, basestring):
            data = data.splitlines()
        output = []
        for i, line in enumerate(data):
            output_line = []
            current_fg = current_bg = -1
            for j, ch in enumerate(line):
                fg, bg = colmap[i][j]
                new_fg = new_bg = None
                if fg != current_fg:
                    new_fg = current_fg = fg
                    current_fg = fg
                if bg != current_bg:
                    new_bg = current_bg = bg
                    current_bg = bg
                if new_fg or new_bg:
                    pass
                output_line.append(ch)
            output.append(''.join(output_line))
        return output

    @property
    def color_re(self):
        return self.styles[self.style]['color']

    @property
    def parse_re(self):
        return self.styles[self.style]['parse']

    @property
    def map(self):
        return self.styles[self.style]['map']


def main():
    style = 'mirc'
    color = Color(style)
    with open(style + '.txt', 'rb') as file:
        data = file.read()
    lines, colmap = color.decode(data)
    print '\n'.join(lines)
    color.style = 'ansi'
    lines = color.encode(lines, colmap)
    print '\n'.join(lines)
    return 0

if __name__ == '__main__':
    sys.exit(main())
