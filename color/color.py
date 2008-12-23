#!/usr/bin/env python

import sys
import re
import codecs

class ColorMapError(Exception):

    pass


class ColorMap(object):

    """Class to manage an ANSI/mIRC color-mapped text string"""

    schemes = {
            'mirc': {
                'color_re': re.compile('(\x03[0-9,]+\x16*|\x0f)'),
                },
            'ansi': {
                'color_re': re.compile('(\x1b\[[0-9;]+m)'),
                },
            'plain': {
                'color_re': re.compile('(\xff)'),
                },
            }

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
        self.plain, self.colormap = self.decode(data, scheme)
        self.scheme = scheme
        self.encoding = encoding

    @property
    def color_re(self):
        return self.schemes[self.scheme]['color_re']

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
        color_re = cls.schemes[scheme]['color_re']
        for line in data.splitlines():
            plain_line = []
            colmap_line = []
            current_color = None
            for part in color_re.split(line):
                if not part:
                    continue
                if color_re.match(part):
                    current_color = part
                else:
                    plain_line.append(part)
            plain.append(''.join(plain_line))
        return plain, colmap

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
