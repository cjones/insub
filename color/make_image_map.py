#!/usr/bin/env python

"""Generate a colormap from an image"""

from __future__ import with_statement
from optparse import OptionParser
import sys
import PIL.Image
import os
import math
import time

# approximate RGB values of our available ANSI colors, based on iTerm
iterm = (('d', (0, 0, 0)),
         ('D', (85, 85, 85)),
         ('r', (205, 0, 0)),
         ('R', (255, 80, 86)),
         ('g', (0, 192, 0)),
         ('G', (0, 255, 69)),
         ('y', (184, 190, 0)),
         ('Y', (252, 255, 71)),
         ('b', (24, 0, 192)),
         ('B', (92, 75, 255)),
         ('m', (207, 0, 192)),
         ('M', (255, 69, 255)),
         ('c', (0, 189, 188)),
         ('C', (0, 255, 255)),
         ('w', (187, 187, 187)),
         ('W', (255, 255, 255)))

# more "pure" version of RGB primary colors (high contrast between light/dark)
pure = (('d', (0, 0, 0)),
        ('D', (85, 85, 85)),
        ('r', (128, 0, 0)),
        ('R', (255, 0, 0)),
        ('g', (0, 128, 0)),
        ('G', (0, 255, 0)),
        ('y', (128, 128, 0)),
        ('Y', (255, 255, 0)),
        ('b', (0, 0, 128)),
        ('B', (0, 0, 255)),
        ('m', (128, 0, 128)),
        ('M', (255, 0, 255)),
        ('c', (0, 128, 128)),
        ('C', (0, 255, 255)),
        ('w', (171, 171, 171)),
        ('W', (255, 255, 255)))


def fix_flesh_tone(rgb):
    """Transforms fleshtones into something more yellow (experimental)"""
    # XXX the range it considers flesh is pretty wide and can cause some
    # unwanted blending.  a better solution might be to tighten the range
    # it considers flesh and allow the user to specify a skew that relates
    # to the skin tone of the subject.  this might even be auto-detected by
    # a color count.  right now this is better than nothing though.  without
    # this adjustment, most photographs of people turn into a slop of grey.
    #
    # another candidate for adjustment is the +37 to r/g.. the point of this
    # is to put the midpoint of flesh tones around the midpoint of ansi
    # dark yellow/bright yellow.  then lighting or tanlines will show up
    # highlighted. however this will only work with a narrow skin color range
    rgb = list(rgb)
    if (rgb[0] >= 147 and rgb[0] <= 255 and
        rgb[1] >= 107 and rgb[1] <= 217 and
        rgb[2] >= 99  and rgb[2] <= 198):
        rgb[0] += 37
        rgb[1] += 37
        rgb[2] = 0
    return rgb


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


def fill(data, node, color, new):
    """Queue-based color fill"""
    if data[node[0]][node[1]] != color:
        return
    queue = [node]
    while queue:
        x, y = queue.pop(0)
        if data[x][y] == color:
            data[x][y] = new
        for i in [-1 if x > 0 else 0, 1 if x < len(data) - 1 else 0]:
            for j in [-1 if y > 0 else 0, 1 if y < len(data[x]) - 1 else 0]:
                x2, y2 = x + i, y + j
                if data[x2][y2] == color:
                    data[x2][y2] = new
                    queue.append((x2, y2))


def main():
    parser = OptionParser(usage='%prog [-lci] [-b <char>] [-o <map>] <image>')
    parser.add_option('-o', dest='output', metavar='<file>', help='output map')
    parser.add_option('-c', dest='correct', default=False, action='store_true',
                      help='correct aspect ratio (prevent stretched map)')
    parser.add_option('-f', dest='flesh', default=False, action='store_true',
                      help='make flesh tones more yellow')
    parser.add_option('-b', dest='bgfill', metavar='<char>',
                      help='fill background with this color')
    parser.add_option('-i', dest='palette', default=pure,
                      action='store_const', const=iterm,
                      help='use iterm palette (darker)')
    parser.add_option('-l', dest='distance',
                      default=weighted_color_dist, action='store_const',
                      const=euclidean_color_dist, help='linear color distance')
    opts, args = parser.parse_args()

    # check args
    if len(args) != 1:
        parser.print_help()
        return 1
    src = args[0]
    if not opts.output:
        opts.output = os.path.splitext(os.path.basename(src))[0] + '.map'

    # create map
    start = time.time()
    image = PIL.Image.open(src)
    width, height = image.size
    if opts.correct:
        height = int(height * .4286)
        image = image.resize((width, height))
    if image.mode == 'P':
        palette = image.getpalette()
        palette = [palette[i:i + 3] for i in xrange(0, len(palette), 3)]

    # convert pixel data into a map
    data = []
    for y in xrange(height):
        line = []
        for x in xrange(width):
            rgb = image.getpixel((x, y))
            if image.mode == 'P':
                rgb = palette[rgb]
            if opts.flesh:
                rgb = fix_flesh_tone(rgb)
            line.append(sorted(
                [(opts.distance(rgb, code_rgb), code)
                 for code, code_rgb in opts.palette])[0][1])
        data.append(line)

    # figure out what the background color is if fill is requested
    if opts.bgfill:
        edges = {}
        for x in xrange(len(data)):
            if x == 0 or x == len(data) - 1:
                i = xrange(len(data[x]))
            else:
                i = (0, len(data[x]) - 1)
            for y in i:
                edges.setdefault(data[x][y], []).append((x, y))

        color, nodes = sorted(edges.iteritems(),
                              key=lambda item: len(item[1]),
                              reverse=True)[0]

        # fill in background color with the new one
        for node in nodes:
            fill(data, node, color, opts.bgfill)

    # save final map
    with open(opts.output, 'wb') as fp:
        for line in data:
            fp.write(''.join(line))
            fp.write('\n')

    print 'finished in %.2f seconds' % (time.time() - start)
    return 0


if __name__ == '__main__':
    try:
        import psyco
        psyco.cannotcompile(PIL.Image.open)
        psyco.full()
    except ImportError:
        pass
    sys.exit(main())
