#!/usr/bin/env python

from __future__ import with_statement
import sys
import pil.Image
import os

ansi = {
        'd': (0, 0, 0),
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
        'W': (255, 255, 255),
        }

def main():
    for path in sys.argv[1:]:
        img = pil.Image.open(path)
        output = []
        for y in xrange(img.size[1]):
            output_line = []
            for x in xrange(img.size[0]):
                rgb = img.getpixel((x, y))
                deltas = {}
                for code, code_rgb in ansi.iteritems():
                    r_delta = code_rgb[0] - rgb[0]
                    g_delta = code_rgb[1] - rgb[1]
                    b_delta = code_rgb[2] - rgb[2]
                    if r_delta < 0:
                        r_delta *= -1
                    if g_delta < 0:
                        g_delta *= -1
                    if b_delta < 0:
                        b_delta *= -1
                    delta = r_delta + g_delta + b_delta
                    deltas[code] = delta
                deltas = sorted(deltas.iteritems(), key=lambda item: item[1])
                code = deltas[0][0]
                output_line.append(code)
            output.append(''.join(output_line))
        output = '\n'.join(output) + '\n'
        base = os.path.basename(path)
        name = os.path.splitext(base)[0]
        with open(name + '.map', 'wb') as file:
            file.write(output)
    return 0

if __name__ == '__main__':
    sys.exit(main())
