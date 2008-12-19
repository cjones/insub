#!/usr/bin/env python

import sys
import re

class ColorError(Exception):

    pass


class Color(object):

    colors = ['black',    # 0
              'white',    # 1
              'red',      # 2
              'yellow',   # 3
              'green',    # 4
              'cyan',     # 5
              'blue',     # 6
              'magenta']  # 7

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
    return 0

if __name__ == '__main__':
    sys.exit(main())
