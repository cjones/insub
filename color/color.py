#!/usr/bin/env python

import sys
import re
import codecs

class ColorMapError(Exception):

    pass


class ColorMap(object):

    """Class to manage an ANSI/mIRC color-mapped text string"""

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
               'plain': {'color_re': re.compile('(\xff)'),
                         'parse_re': re.compile('(\xff)')}}

    reset = (7,      # fg
             False,  # intense
             0,      # bg
             True)   # default

    def __init__(self, data=None, scheme=None, encoding=None):
        """Instantiate a color-mapped text string"""

        # try to determine encoding of source data
        if not encoding and hasattr(data, 'encoding'):
            encoding = data.encoding
        try:
            encoding = codecs.lookup(encoding).name
        except:
            encoding = sys.getdefaultencoding()

        # file-like objects return lines with newlines intact,
        # other iterables return stripped lines
        if hasattr(data, 'read'):
            data = ''.join(data)
        elif hasattr(data, '__iter__'):
            data = '\n'.join(data)

        # make sure data is unicode
        if data is None:
            data = u''
        elif isinstance(data, str):
            data = data.decode(encoding, 'replace')
        if not isinstance(data, unicode):
            raise ColorMapError('unknown data type: %s' % type(data))

        # verify scheme is valid
        if scheme is None:
            scheme = self.detect(data)
        if scheme not in self.schemes:
            raise ColorMapError('unknown scheme: %s' % scheme)

        # store decoded version
        self.plain, self.colmap = self.decode(data, scheme)
        self.scheme = scheme
        self.encoding = encoding

    @property
    def color_re(self):
        return self.schemes[self.scheme]['color_re']

    @property
    def parse_re(self):
        return self.schemes[self.scheme]['parse_re']

    @classmethod
    def detect(cls, data):
        """Try to guess color scheme"""
        seen = {}
        for scheme in cls.schemes:
            seen[scheme] = len(cls.schemes[scheme]['color_re'].findall(data))
        if sum(seen.values()):
            return sorted(seen.iteritems(),
                          key=lambda item: item[1],
                          reverse=True)[0][0]
        return 'plain'

    @classmethod
    def decode(cls, data, scheme):
        """Returns decoded plain text and its colormap from text"""

        # sanity check inputs
        if not isinstance(data, unicode):
            raise ColorMapError('decode requires unicode data')
        if scheme not in cls.schemes:
            raise ColorMapError('unknown scheme: %s' % scheme)

        # decode
        plain = []
        colmap = []
        attrs = cls.schemes[scheme]
        for line in data.splitlines():
            plain_line = []
            colmap_line = []
            fg, intense, bg, default = cls.reset
            for part in attrs['color_re'].split(line):
                if not part:
                    continue
                if attrs['color_re'].match(part):
                    if part == '\x0f':
                        fg, intense, bg, default = cls.reset
                    else:
                        part = attrs['parse_re'].search(part).groups()
                        default = False
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
                                    intense = True
                                elif part in (2, 22):
                                    intense = False
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
                    plain_line.append(part)
                    col = cls.pack(fg, intense, bg, default)
                    colmap_line.append(col * len(part))
            plain.append(''.join(plain_line))
            colmap.append(''.join(colmap_line))
        return plain, colmap

    @classmethod
    def encode(cls, lines, colmap, scheme):
        """Encode in color"""

    @staticmethod
    def pack(fg, intense=False, bg=0, default=False):
        """Pack color -> char"""
        return chr((fg & 7) +
                   ((1 if intense else 0) << 3) +
                   ((bg & 7) << 4) +
                   ((1 if default else 0) << 7))

    @staticmethod
    def unpack(char):
        """Unpack color -> (fg, intense, bg, default)"""
        char = ord(char)
        return ((char & 7), bool((char & 8) >> 3),
                (char & 112) >> 4, bool((char & 128) >> 7))

    def __iter__(self):
        for line in self.plain:
            yield line

    def __str__(self):
        return '\n'.join(self).encode(self.encoding, 'replace')

    def __repr__(self):
        return '<%s object at 0x%x: lines=%d, scheme=%s, encoding=%s>' % (
                self.__class__.__name__, id(self), len(self.plain),
                self.scheme, self.encoding)


def main():
    for path in sys.argv[1:]:
        with open(path, 'r') as file:
            col = ColorMap(file, encoding='utf8')
        print repr(col)
        print col
    return 0


if __name__ == '__main__':
    sys.exit(main())
