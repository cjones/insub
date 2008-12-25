#!/usr/bin/env python

"""Change background color of a map"""

import sys
import optparse

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
    parser = optparse.OptionParser(usage='%prog [-n <char>] <mapfile>')
    parser.add_option('-n', dest='new', metavar='<char>', default='d',
                      help='new background char (default: %default)')
    parser.add_option('-o', dest='output', metavar='<file>', help='output file')
    opts, args = parser.parse_args()

    # load source map
    if len(args) != 1:
        parser.print_help()
        return 1
    src = args[0]
    if not opts.output:
        opts.output = os.path.splitext(os.path.basename(src))[0] + '.filled'

    # load map
    with open(src, 'r') as fp:
        data = [list(line.strip()) for line in fp.readlines()]

    # figure out what the background color is
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
        fill(data, node, color, opts.new)

    # save transformed map
    with open(opts.output, 'wb') as fp:
        for line in data:
            for ch in line:
                fp.write(ch)
            fp.write('\n')

    return 0


if __name__ == '__main__':
    try:
        import psyco
        psyco.full()
    except ImportError:
        pass
    sys.exit(main())
