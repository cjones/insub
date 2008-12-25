#!/usr/bin/env python

from __future__ import with_statement
from optparse import OptionParser
import sys
import PIL.Image
import os
import math

"""Generate a colormap from an image"""

# approximate RGB values of our available ANSI colors, based on iTerm
iterm = {'d': (0, 0, 0),
         'D': (85, 85, 85),
         'r': (205, 0, 0),
         'R': (255, 80, 86),
         'g': (0, 192, 0),
         'G': (0, 255, 69),
         'y': (184, 190, 0),
         'Y': (252, 255, 71),
         'b': (24, 0, 192),
         'B': (92, 75, 255),
         'm': (207, 0, 192),
         'M': (255, 69, 255),
         'c': (0, 189, 188),
         'C': (0, 255, 255),
         'w': (187, 187, 187),
         'W': (255, 255, 255)}

# more "pure" version of RGB primary colors, i guess
pure = {'d': (0, 0, 0),
        'D': (85, 85, 85),
        'r': (128, 0, 0),
        'R': (255, 0, 0),
        'g': (0, 128, 0),
        'G': (0, 255, 0),
        'y': (128, 128, 0),
        'Y': (252, 255, 0),
        'b': (0, 0, 128),
        'B': (0, 0, 255),
        'm': (128, 0, 128),
        'M': (255, 0, 255),
        'c': (0, 128, 128),
        'C': (0, 255, 255),
        'w': (171, 171, 171),
        'W': (255, 255, 255)}



def euclidean_color_dist(x, y):
    """Linear XYZ distance between two RGB points"""
    return int(math.sqrt((x[0] - y[0]) ** 2 +
                         (x[1] - y[1]) ** 2 +
                         (x[2] - y[2]) ** 2))


def weighted_color_dist(x, y):
    """Color distance between two RGB points, weighted by red level"""
    # explained here: http://www.compuphase.com/cmetric.htm
    rmean = (x[0] + y[0]) / 2
    return math.sqrt((((512 + rmean) * ((x[0] - y[0]) ** 2)) >> 8) + 4 *
                                       ((x[1] - y[1]) ** 2) +
                     (((767 - rmean) * ((x[2] - y[2]) ** 2)) >> 8))


def main():
    parser = OptionParser()
    parser.add_option('-w', '--weighted', dest='distance',
                      default=euclidean_color_dist, action='store_const',
                      const=weighted_color_dist, help='alt color aprox')
    parser.add_option('-c', '--correct', default=False, action='store_true',
                      help='correct aspect ratio')
    parser.add_option('-i', '--iterm', dest='palette', default=pure,
                      action='store_const', const=iterm,
                      help='use iterm palette')
    opts, args = parser.parse_args()

    for src in args:
        name = os.path.basename(src)
        image = PIL.Image.open(src)
        width, height = image.size
        if opts.correct:
            height = int(height * .4286)
            image = image.resize((width, height))
        if image.mode == 'P':
            palette = image.getpalette()
        output = []
        for y in xrange(height):
            for x in xrange(width):
                rgb = image.getpixel((x, y))
                if image.mode == 'P':
                    i = rgb * 3
                    rgb = palette[i:i + 3]
                output.append(sorted(
                    [(opts.distance(rgb, code_rgb), code)
                     for code, code_rgb in opts.palette.iteritems()])[0][1])
            output.append('\n')
        with open(os.path.splitext(name)[0] + '.map', 'wb') as fp:
            fp.write(''.join(output))

    return 0


if __name__ == '__main__':
    try:
        import psyco
        psyco.full()
    except ImportError:
        pass
    sys.exit(main())
