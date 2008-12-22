#!/usr/bin/env python

import sys
import re

class ColorMapError(Exception):

    pass


class ColorMap(object):

    styles = {'mirc': {'color': re.compile('(\x03[0-9,]+\x16*|\x0f)'),
                       'parse': re.compile('\x03([0-9]+)?(?:,([0-9]+))?'),
                       'map': [(1, 7), (0, 0), (0, 4), (0, 2), (1, 1), (0, 1),
                               (0, 5), (0, 3), (1, 3), (1, 2), (0, 6), (1, 6),
                               (1, 4), (1, 5), (1, 0), (0, 7)]},
              'ansi': {'color': re.compile('(\x1b\[[0-9;]+m)'),
                       'parse': re.compile('\x1b\[([0-9;]+)')}}

    default = (7, 0, 0)

    def __init__(self, style):
        if style not in self.styles:
            raise ColorMapError('unknown style: %s' % style)
        self.style = style

    def decode(self, data):
        if isinstance(data, basestring):
            data = data.splitlines()
        lines = []
        colmap = []
        for line in data:
            lines_line = []
            colmap_line = []
            fg, bg, intense = self.default
            for item in self.color_re.split(line):
                if not item:
                    continue
                if self.color_re.match(item):
                    if self.style == 'mirc' and item == '\x0f':
                        fg, bg, intense = self.default
                    else:
                        item = self.parse_re.match(item).groups()
                        if self.style == 'mirc':
                            new_fg, new_bg = item
                            if new_fg:
                                intense, fg = self.map[int(new_fg)]
                            if new_bg:
                                bg = self.map[int(new_bg)][1]
                        elif self.style == 'ansi':
                            for code in item[0].split(';'):
                                code = int(code)
                            if code == 0:
                                fg, bg, intense = self.default
                            elif code == 1:
                                intense = 1
                            elif code in (2, 22):
                                intense = 0
                            elif code == 7:
                                fg, bg = bg, fg
                            elif code == 39:
                                fg = self.default[0]
                            elif code == 49:
                                bg = self.default[1]
                            elif ((code >= 30 and code <= 37) or
                                  (code >= 40 and code <= 47)):
                                code -= 30
                                if code >= 10:
                                    bg = code - 10
                                else:
                                    fg = code
                else:
                    col = chr((bg << 4) + (intense << 3) + fg)
                    colmap_line.append(col * len(item))
                    lines_line.append(item)
            lines.append(''.join(lines_line))
            colmap.append(''.join(colmap_line))
        return lines, colmap

    def encode(self, data, colmap=None):
        if isinstance(data, basestring):
            data = data.splitlines()
        if colmap is None:
            colmap = []
        elif isinstance(colmap, basestring):
            colmap = colmap.splitlines()
        output = []
        for i, line in enumerate(data):
            output_line = []
            fg, bg, intense = self.default
            for j, ch in enumerate(line):
                col = ord(colmap[i][j])
                new_bg = (col & 112) >> 4
                new_intense = (col & 8) >> 3
                new_fg = (col & 7)
                if new_fg != fg or new_bg != bg or new_intense != intense:
                    if self.style == 'mirc':
                        codes = []
                        if new_fg != fg or new_intense != intense:
                            codes.append(self.map.index((new_intense, new_fg)))
                        else:
                            codes.append('')
                        if new_bg != bg:
                            codes.append(self.map.index((0, new_bg)))
                        code = '\x03%s\x16\x16' % ','.join(map(str, codes))
                    elif self.style == 'ansi':
                        codes = []
                        if new_fg != fg:
                            codes.append(30 + new_fg)
                        if new_bg != bg:
                            code.append(40 + new_bg)
                        if new_intense != intense:
                            if new_intense == 1:
                                codes.append(1)
                            else:
                                codes.append(22)
                        code = '\x1b[%sm' % ';'.join(map(str, codes))
                    fg = new_fg
                    bg = new_bg
                    intense = new_intense
                    output_line.append(code)
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
    # XXX don't change if only fg changes and text is whitespace?
    # XXX encode possible with partial color maps?
    # XXX any use for 8th bit?
    # XXX html encoding? :P
    # XXX seems to be some intensity confusion between mirc and ansi?
    # XXX getting about time to see if this is going to work at all w/insub
    style = 'mirc'
    col = ColorMap(style)
    with open(style + '.txt', 'rb') as file:
        data = file.read()
    print data
    lines, colmap = col.decode(data)
    print '\n'.join(lines)
    col.style = 'ansi'
    print '\n'.join(col.encode(lines, colmap))
    return 0

if __name__ == '__main__':
    sys.exit(main())
