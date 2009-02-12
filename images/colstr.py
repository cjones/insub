#!/usr/bin/env python

"""Colored unicode type"""

import sys
import re

__version__ = '0.1'
__author__ = 'Chris Jones <cjones@gruntle.org>'
__license__ = 'BSD'
__all__ = ['colstr']

def coerce(func):

    """Internal: decorator to coerce all args and keyword args that are
    bare strings into colstr objects, inheriting their properties from
    the original.  This operation is recursive on all nested primitive
    data types except for the keys of dictionaries, since this would
    cause undefined and unexpected lookup behavior, as well as breaking
    keyword arguments.

    This decorator should be applied to any function who may be taking
    strings as parameters so that our functions can always assume they
    have colstr objects to work with and that they are properly
    decoded."""

    def conv(item, opts):
        """Recursive converstion function"""
        if isinstance(item, basestring):
            return colstr(item, **opts)
        if isinstance(item, tuple):
            return tuple(conv(x, opts) for x in item)
        if isinstance(item, list):
            return list(conv(x, opts) for x in item)
        if isinstance(item, dict):
            return dict((x, conv(y, opts)) for x, y in item.iteritems())
            #return dict(conv(x, opts) for x in item.iteritems())
        return item

    def inner(self, *args, **kwargs):
        """Wrapper function"""
        # none of these are auto-detected in a useful way, so best
        # inherit them from someone that knows wtf is going on.
        opts = {'encoding': self.encoding, 'errors': self.errors,
                'newline': self.newline}
        args = conv(args, opts)
        kwargs = conv(kwargs, opts)
        return func(self, *args, **kwargs)

    # lie about who we are so that help() is still useful
    inner.__name__ = func.__name__
    inner.__doc__ = func.__doc__
    return inner


class colstr(object):

    """colstr([string [, encoding[, scheme[, errors[, newline]]]]]) -> object

    Create a new color-mapped Unicode object from the given string.
    encoding defaults to the current default string encoding.
    scheme can be 'ansi', 'mirc' or 'plain' and defaults to auto-detect.
    errors can be 'strict', 'replace' or 'ignore' and defaults to 'strict'.
    newline style can be 'reset' or 'ignore' and indicate whether color
    gets reset to its default on a new line (such as IRC) or if the color
    it was changed to continues (some shells).  default is 'reset'.

    The colstr object can be manipulated like regular unicode objects
    while keeping the underlyingn color information in tact.  Call the
    render() method to encode into ANSI or mIRC colors."""

    # mapping by color name
    colnames = ['black',    # 0
                'red',      # 1
                'green',    # 2
                'yellow',   # 3
                'blue',     # 4
                'magenta',  # 5
                'cyan',     # 6
                'white']    # 7

    # mapping by color code (uppercase = intensity on)
    codes = ['d', 'r', 'g', 'y', 'b', 'm', 'c', 'w']

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
               # dummy entry to handle uncolored text
               'plain': {'color_re': re.compile('(\xff)'),
                         'parse_re': re.compile('(\xff)')}}

    # the default color scheme (white on black)
    reset = (7,  # foreground color
             0,  # intensity on
             0,  # background color
             1)  # default flag indicates color has not changed

    newline_re = re.compile(r'(\n)')

    # this evil little thing parses python old-style string modulo formats
    # http://docs.python.org/3.0/library/stdtypes.html
    fmt_re = re.compile(r'''%                     # start of format option
                            (?:\((.*?)\))?        # optional mapping key
                            ([#0 +-]*?)           # optional conversion flags
                            (\*|[0-9]+?)?         # optional field width
                            (?:\.(\*|[0-9]+?))?   # optional precision
                            [hlL]?                # ignored length modifier
                            ([diouxXeEfFgGcrs%])  # conversion type
                            ''', re.VERBOSE)


    def __init__(self, string=None, encoding=None, scheme=None, errors=None,
                 newline='reset'):
        if encoding is None:
            encoding = sys.getdefaultencoding()
        if errors is None:
            errors = 'strict'
        if string is None:
            string = u''
        elif isinstance(string, colstr):
            self.__dict__.update(string.__dict__)
            return
        elif not isinstance(string, unicode):
            string = unicode(string, encoding, errors)
        if scheme is None:
            scheme = self.detect(string)
        if newline not in ('reset', 'ignore'):
            raise ValueError("newline style must be 'reset' or 'ignore'")
        self.plain, self.colmap = self.decode(string, scheme, newline)
        self.encoding = encoding
        self.scheme = scheme
        self.errors = errors
        self.newline = newline

    def render(self, scheme=None):
        """self.render([scheme]) -> unicode

        Renders the colstr object into unicode with the color data for
        the given scheme added."""
        if scheme is None:
            scheme = self.scheme
        return self.encode(self.plain, self.colmap, scheme)

    def clone(self, plain=None, colmap=None):
        """Create a new instance of the same colstr.  Initial values for
        plain and/or colmap may be provided.  If plain is larger than the
        colormap, it will be padding with default values.  If colmap is larger,
        it will be truncated to fit"""
        new = colstr(self)
        if plain is not None:
            new.plain = plain
        if colmap is not None:
            new.colmap = colmap
        offset = len(new.plain) - len(new.colmap)
        if offset > 0:
            # plain is larger than colmap, add defaults to colmap
            new.colmap += self.reset_char * offset
        elif offset < 0:
            # colamp is larger than plain, chomp chomp
            new.colmap = new.colmap[:offset]
        # assert the above worked
        if len(new.plain) != len(new.colmap):
            raise ValueError('plain/colmap size mismatch')
        return new

    ##################
    ### PROPERTIES ###
    ##################

    @property
    def reset_char(self):
        """Packed reset character"""
        return self.pack(*self.reset)

    #####################
    ### CLASS METHODS ###
    #####################

    @classmethod
    def detect(cls, string):
        """Try to guess color scheme from the given seq of raw bytes"""
        seen = {}
        for scheme, data in cls.schemes.iteritems():
            seen[scheme] = len(data['color_re'].findall(string))
        if sum(seen.values()):
            return max(seen.iteritems(), key=lambda item: item[1])[0]
        return 'plain'

    @classmethod
    def decode(cls, data, scheme, newline='reset'):
        """Returns decoded plain text and its colormap from text"""

        # sanity check inputs
        if not isinstance(data, unicode):
            raise TypeError('decode requires unicode data')
        if scheme not in cls.schemes:
            raise ValueError('unknown scheme: %s' % scheme)

        # decode
        plain = []
        colmap = []
        attrs = cls.schemes[scheme]
        fg, intense, bg, default = cls.reset
        for cpart in attrs['color_re'].split(data):
            for part in cls.newline_re.split(cpart):
                if not part:
                    continue
                if attrs['color_re'].match(part):
                    if part == '\x0f':
                        fg, intense, bg, default = cls.reset
                    else:
                        part = attrs['parse_re'].search(part).groups()
                        default = 0
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
                                    intense = 1
                                elif part in (2, 22):
                                    intense = 0
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
                    if newline == 'reset' and part == '\n':
                        fg, intense, bg, default = cls.reset
                    plain.append(part)
                    col = cls.pack(fg, intense, bg, default)
                    colmap.append(col * len(part))
        return u''.join(plain), ''.join(colmap)

    @classmethod
    def encode(cls, plain, colmap, scheme):
        """Encode the plain/colmap pair in color using provided scheme"""

        # sanity check inputs
        if scheme not in cls.schemes:
            raise ValueError('unknown scheme: %s' % scheme)

        # encode
        attrs = cls.schemes[scheme]
        output = []
        last = list(cls.reset)
        for i, zipped in enumerate(zip(plain, colmap)):
            ch, col = zipped[0], list(cls.unpack(zipped[1]))
            try:
                next = plain[i + 1]
            except IndexError:
                next = None

            # what's changed?
            fg_changed = col[0] != last[0]
            intense_changed = col[1] != last[1]
            bg_changed = col[2] != last[2]

            # the conditions under which we will need to repaint
            if bg_changed or (ch != ' ' and (fg_changed or intense_changed)):
                outcol = None
                if scheme == 'mirc':
                    if col[3]:
                        outcol = '\x0f'
                    else:
                        codes = []
                        if fg_changed or intense_changed:
                            newcol = attrs['map'].index((col[1], col[0]))
                            codes.append(str(newcol))
                        if bg_changed:
                            if not codes:
                                codes.append('')
                            newcol = attrs['map'].index((0, col[2]))
                            codes.append(str(newcol))
                        outcol = '\x03%s' % ','.join(codes)
                        if next and next.isdigit():
                            outcol += '\x16\x16'
                elif scheme == 'ansi':
                    codes = []
                    if col[3]:
                        codes.append(0)
                    else:
                        if fg_changed:
                            codes.append(col[0] + 30)
                        if bg_changed:
                            codes.append(col[2] + 40)
                        if intense_changed:
                            if col[1]:
                                codes.append(1)
                            else:
                                codes.append(22)
                    outcol = '\x1b[%sm' % ';'.join(map(str, codes))
                if outcol:
                    last = col
                    output.append(outcol)

            output.append(ch)
        return u''.join(output)

    @staticmethod
    def pack(fg, intense=0, bg=0, default=1):
        """Pack color -> char"""
        return chr(fg + (intense << 3) + (bg << 4) + (default << 7))

    @staticmethod
    def unpack(char):
        """Unpack color -> (fg, intense, bg, default)"""
        char = ord(char)
        return ((char & 7), (char & 8) >> 3,
                (char & 112) >> 4, (char & 128) >> 7)

    #########################################################
    ### UTILITY CLASS METHODS NOT USED BY THE COLSTR TYPE ###
    #########################################################

    @classmethod
    def compile(cls, map):
        """Compile a letter-coded map into packed version"""
        compiled = []
        for ch in map:
            if ch.isupper():
                intense = 1
                ch = ch.lower()
            else:
                intense = 0
            compiled.append(cls.pack(cls.codes.index(ch), intense, default=0))
        return ''.join(compiled)

    @classmethod
    def pack_by_name(cls, name):
        """Return the packed color value by name"""

        # XXX this whole function should be greatly simplified..
        # but at least it works, will be useful somewhere i think.
        name = name.lower()
        name = name.replace('dark', '')
        name = name.replace('light', 'bright')
        name = name.replace('gray', 'grey')
        name = name.replace('orange', 'bright red')
        name = name.replace('purple', 'magenta')
        name = name.split()
        if 'on' not in name:
            name += ['on', 'black']
        on = name.index('on')

        # grey -> bright black
        # bright grey -> white
        # white -> bright white
        def fixgrey(words):
            if 'grey' in words:
                if 'bright' in words:
                    return ['white']
                else:
                    return ['bright', 'black']
            elif 'white' in words:
                return ['bright', 'white']
            else:
                return words

        fg, intense, bg, default = cls.reset
        for word in fixgrey(name[:on]):
            if word == 'bright':
                intense = 1
                default = 0
            elif word in cls.colnames:
                fg = cls.colnames.index(word)
                default = 0
        for word in fixgrey(name[on + 1:]):
            if word in cls.colnames:
                bg = cls.colnames.index(word)
                default = 0

        char = cls.pack(fg, intense, bg, default)
        return char

    ##########################
    ### INTERNAL FUNCTIONS ###
    ##########################

    def __str__(self):
        """x.__str__() <==> str(x)"""
        return self.plain
        #return self.render('ansi').encode('utf8', 'replace')

    def __repr__(self):
        return repr(self.plain).replace('u', 'c', 1)

    def __iter__(self):
        for i in xrange(len(self)):
            yield self[i]

    #################################
    ### OVERLOAD GLOBAL OPERATORS ###
    #################################

    def __mul__(x, n):
        """x.__mul__(n) <==> x*n"""
        return x.clone(x.plain * n, x.colmap * n)

    __rmul__ = __mul__

    def __len__(x):
        """x.__len__() <==> len(x)"""
        return len(x.plain)

    def __getitem__(x, y):
        """x.__getitem__(y) <==> x[y]"""
        return x.clone(x.plain[y], x.colmap[y])

    def __getslice__(x, i, j):
        """x.__getslice__(i, j) <==> x[i:j]"""
        return x.clone(x.plain[i:j], x.colmap[i:j])

    @coerce
    def __add__(x, y):
        """x.__add__(y) <==> x+y"""
        return x.clone(x.plain + y.plain, x.colmap + y.colmap)

    ################################
    ### CAPITALIZATION FUNCTIONS ###
    ################################

    def capitalize(S):
        """S.capitalize() -> colstr

        Return a capitalized version of S, i.e. make the first character
        have upper case."""
        return S.clone(S.plain.capitalize())

    def lower(S):
        """S.lower() -> colstr

        Return a copy of the string S converted to lowercase."""
        return S.clone(S.plain.lower())

    def upper(S):
        """S.upper() -> colstr

        Return a copy of S converted to uppercase."""
        return S.clone(S.plain.upper())

    def swapcase(S):
        """S.swapcase() -> colstr

        Return a copy of S with uppercase characters converted to lowercase
        and vice versa."""
        return S.clone(S.plain.swapcase())

    def title(S):
        """S.title() -> colstr

        Return a titlecased version of S, i.e. words start with title case
        characters, all remaining cased characters have lower case."""
        return S.clone(S.plain.title())

    ####################
    ### RETURN BOOLS ###
    ####################

    def isalnum(S):
        """S.isalnum() -> bool

        Return True if all characters in S are alphanumeric
        and there is at least one character in S, False otherwise."""
        return S.plain.isalnum()

    def isalpha(S):
        """S.isalpha() -> bool

        Return True if all characters in S are alphabetic
        and there is at least one character in S, False otherwise."""
        return S.plain.isalpha()

    def isdecimal(S):
        """S.isdecimal() -> bool

        Return True if there are only decimal characters in S,
        False otherwise."""
        return S.plain.isdecimal()

    def isdigit(S):
        """S.isdigit() -> bool

        Return True if all characters in S are digits
        and there is at least one character in S, False otherwise."""
        return S.plain.isdigit()

    def islower(S):
        """S.islower() -> bool

        Return True if all cased characters in S are lowercase and there is
        at least one cased character in S, False otherwise."""
        return S.plain.islower()

    def isnumeric(S):
        """S.isnumeric() -> bool

        Return True if there are only numeric characters in S,
        False otherwise."""
        return S.plain.isnumeric()

    def isspace(S):
        """S.isspace() -> bool

        Return True if all characters in S are whitespace
        and there is at least one character in S, False otherwise."""
        return S.plain.isspace()

    def istitle(S):
        """S.istitle() -> bool

        Return True if S is a titlecased string and there is at least one
        character in S, i.e. upper- and titlecase characters may only
        follow uncased characters and lowercase characters only cased ones.
        Return False otherwise."""
        return S.plain.istitle()

    def isupper(S):
        """S.isupper() -> bool

        Return True if all cased characters in S are uppercase and there is
        at least one cased character in S, False otherwise."""
        return S.plain.isupper()

    @coerce
    def startswith(S, prefix, *args):
        """S.startswith(prefix[, start[, end]]) -> bool

        Return True if S starts with the specified prefix, False otherwise.
        With optional start, test S beginning at that position.
        With optional end, stop comparing S at that position.
        prefix can also be a tuple of strings to try."""
        return S.plain.startswith(prefix.plain, *args)

    @coerce
    def endswith(S, suffix, *args):
        """S.endswith(suffix[, start[, end]]) -> bool

        Return True if S ends with the specified suffix, False otherwise.
        With optional start, test S beginning at that position.
        With optional end, stop comparing S at that position.
        suffix can also be a tuple of strings to try."""
        return S.plain.endswith(suffix.plain, *args)

    @coerce
    def __contains__(x, y):
        """x.__contains__(y) <==> y in x"""
        return y.plain in x.plain

    @coerce
    def __eq__(x, y):
        """x.__eq__(y) <==> x==y"""
        return x.plain == y.plain

    @coerce
    def __ge__(x, y):
        """x.__ge__(y) <==> x>=y"""
        return x.plain >= y.plain

    @coerce
    def __gt__(x, y):
        """x.__gt__(y) <==> x>y"""
        return x.plain > y.plain

    @coerce
    def __le__(x, y):
        """x.__le__(y) <==> x<=y"""
        return x.plain <= y.plain

    @coerce
    def __lt__(x, y):
        """x.__lt__(y) <==> x<y"""
        return x.plain < y.plain

    @coerce
    def __ne__(x, y):
        """x.__ne__(y) <==> x!=y"""
        return x.plain != y.plain

    ################
    ### INDEXING ###
    ################

    @coerce
    def count(S, sub, *args):
        """S.count(sub[, start[, end]]) -> int

        Return the number of non-overlapping occurrences of substring sub in
        Unicode string S[start:end].  Optional arguments start and end are
        interpreted as in slice notation."""
        return S.plain.count(sub.plain, *args)

    @coerce
    def find(S, sub, *args):
        """S.find(sub [,start [,end]]) -> int

        Return the lowest index in S where substring sub is found,
        such that sub is contained within s[start:end].  Optional
        arguments start and end are interpreted as in slice notation.

        Return -1 on failure."""
        return S.plain.find(sub.plain, *args)

    @coerce
    def rfind(S, sub, *args):
        """S.rfind(sub [,start [,end]]) -> int

        Return the highest index in S where substring sub is found,
        such that sub is contained within s[start:end].  Optional
        arguments start and end are interpreted as in slice notation.

        Return -1 on failure."""
        return S.plain.rfind(sub.plain, *args)

    @coerce
    def index(S, sub, *args):
        """S.index(sub [,start [,end]]) -> int

        Like S.find() but raise ValueError when the substring is not found."""
        return S.plain.index(sub.plain, *args)

    @coerce
    def rindex(S, sub, *args):
        """S.rindex(sub [,start [,end]]) -> int

        Like S.rfind() but raise ValueError when the substring is not found."""
        return S.plain.rindex(sub.plain, *args)

    #################
    ### SPLITTING ###
    #################

    @coerce
    def partition(S, sep):
        """S.partition(sep) -> (head, sep, tail)

        Searches for the separator sep in S, and returns the part before it,
        the separator itself, and the part after it.  If the separator is not
        found, returns S and two empty strings."""
        try:
            i = S.index(sep)
        except ValueError:
            return S.clone(), S.clone(u''), S.clone(u'')
        j = i + len(sep)
        return S[:i], S[i:j], S[j:]

    @coerce
    def rpartition(S, sep):
        """S.rpartition(sep) -> (tail, sep, head)

        Searches for the separator sep in S, starting at the end of S, and
        returns the part before it, the separator itself, and the part after
        it.  If the separator is not found, returns two empty strings and S."""
        try:
            i = S.rindex(sep)
        except ValueError:
            return S.clone(u''), S.clone(u''), S.clone()
        j = i + len(sep)
        return S[:i], S[i:j], S[j:]

    @coerce
    def split(S, *args):
        """S.split([sep [,maxsplit]]) -> list of strings

        Return a list of the words in S, using sep as the
        delimiter string.  If maxsplit is given, at most maxsplit
        splits are done. If sep is not specified or is None, any
        whitespace string is a separator and empty strings are
        removed from the result."""

        # this function is complicated enough wrt the colormap that
        # we need to implement the split algorithm in python, sadly
        if not args:
            sep, maxsplit = None, None
        elif len(args) == 1:
            sep, maxsplit = args[0], None
        elif len(args) == 2:
            sep, maxsplit = args
        else:
            raise TypeError(
                    'split() takes at most 2 arguments (%d given)' % len(args))

        if sep is None:
            sep_re = re.compile(r'\s+')
        else:
            sep_re = re.compile(re.escape(sep.plain))

        parts = []
        plain, colmap = S.plain, S.colmap
        while plain:
            if maxsplit is not None and len(parts) == maxsplit:
                break
            match = sep_re.search(plain)
            if not match:
                break
            start, stop = match.span()
            parts.append(S.clone(plain[:start], colmap[:start]))
            plain, colmap = plain[stop:], colmap[stop:]
        parts.append(S.clone(plain, colmap))
        if sep is None:
            parts = [part for part in parts if part]
        return parts

    @coerce
    def rsplit(S, *args):
        """S.rsplit([sep [,maxsplit]]) -> list of strings

        Return a list of the words in S, using sep as the
        delimiter string, starting at the end of the string and
        working to the front.  If maxsplit is given, at most maxsplit
        splits are done. If sep is not specified, any whitespace string
        is a separator."""

        # this function is complicated enough wrt the colormap that
        # we need to implement the split algorithm in python, sadly
        # it gets worse with rsplit.. but hey it works.
        if not args:
            sep, maxsplit = None, None
        elif len(args) == 1:
            sep, maxsplit = args[0], None
        elif len(args) == 2:
            sep, maxsplit = args
        else:
            raise TypeError(
                    'split() takes at most 2 arguments (%d given)' % len(args))

        if sep is None:
            sep_re = re.compile(r'\s+')
        else:
            sep_re = re.compile(re.escape(sep.plain))

        parts = []
        plain = ''.join(reversed(S.plain))
        colmap = ''.join(reversed(S.colmap))
        while plain:
            if maxsplit is not None and len(parts) == maxsplit:
                break
            match = sep_re.search(plain)
            if not match:
                break
            start, stop = match.span()
            parts.append(S.clone(''.join(reversed(plain[:start])),
                                 ''.join(reversed(colmap[:start]))))
            plain, colmap = plain[stop:], colmap[stop:]
        parts.append(S.clone(''.join(reversed(plain)),
                             ''.join(reversed(colmap))))
        if sep is None:
            parts = [part for part in parts if part]
        return list(reversed(parts))

    def splitlines(S, keepends=False):
        """S.splitlines([keepends]]) -> list of strings

        Return a list of the lines in S, breaking at line boundaries.
        Line breaks are not included in the resulting list unless keepends
        is given and true."""

        # this function is complicated enough wrt the colormap that
        # we need to implement the split algorithm in python, sadly
        # splitlines is slightly less complicated, thankfully, due to
        # not needing to specify sep or maxsplit and no rsplitlines
        sep_re = re.compile(r'(\r\n|[\r\n])')
        parts = []
        plain, colmap = S.plain, S.colmap
        while plain:
            match = sep_re.search(plain)
            if not match:
                break
            start, stop = match.span()
            line = S.clone(plain[:start], colmap[:start])
            if keepends:
                line += S.clone(plain[start:stop], colmap[start:stop])
            parts.append(line)
            plain, colmap = plain[stop:], colmap[stop:]
        parts.append(S.clone(plain, colmap))
        return parts

    @coerce
    def join(S, sequence):
        """S.join(sequence) -> colstr

        Return a string which is the concatenation of the strings in the
        sequence.  The separator between elements is S."""
        sequence = list(sequence)  # in case it's a generator
        return S.clone(S.plain.join(item.plain for item in sequence),
                       S.colmap.join(item.colmap for item in sequence))

    #############################
    ### MANIPULATE WHITESPACE ###
    #############################

    @coerce
    def strip(S, chars=None):
        """S.strip([chars]) -> colstr

        Return a copy of the string S with leading and trailing
        whitespace removed.
        If chars is given and not None, remove characters in chars instead.
        If chars is a str, it will be converted to colstr before stripping"""
        return S.lstrip(chars).rstrip(chars)

    @coerce
    def lstrip(S, chars=None):
        """S.lstrip([chars]) -> colstr

        Return a copy of the string S with leading whitespace removed.
        If chars is given and not None, remove characters in chars instead.
        If chars is a str, it will be converted to colstr before stripping"""
        orig_size = len(S.plain)
        new = S.clone()
        if isinstance(chars, colstr):
            chars = chars.plain
        new.plain = new.plain.lstrip(chars)
        new.colmap = new.colmap[orig_size - len(new.plain):]
        return new

    @coerce
    def rstrip(S, chars=None):
        """S.rstrip([chars]) -> colstr

        Return a copy of the string S with trailing whitespace removed.
        If chars is given and not None, remove characters in chars instead.
        If chars is a str, it will be converted to colstr before stripping"""
        orig_size = len(S.plain)
        new = S.clone()
        if isinstance(chars, colstr):
            chars = chars.plain
        new.plain = new.plain.rstrip(chars)
        x = (orig_size - len(new.plain)) * -1
        if x < 0:
            new.colmap = new.colmap[:x]
        return new

    def expandtabs(S, tabsize=8):
        """S.expandtabs([tabsize]) -> colstr

        Return a copy of S where all tab characters are expanded using spaces.
        If tabsize is not given, a tab size of 8 characters is assumed."""
        out = []
        for ch in S:
            if ch == '\t':
                ch = S.clone(u' ' * tabsize, ch.colmap * tabsize)
            out.append(ch)
        return S.clone(u'').join(out)

    #####################
    ### JUSTIFICATION ###
    #####################

    @coerce
    def center(S, width, fillchar=None):
        """S.center(width[, fillchar]) -> colstr

        Return S centered in a Unicode string of length width. Padding is
        done using the specified fill character (default is a space)"""
        if fillchar is None:
            fillchar = S.clone(u' ', S.reset_char)
        pad = fillchar * int((width - len(S)) / 2)
        out = [pad, S, pad]
        if width % 2:
            out.insert(0, fillchar)
        return S.clone(u'').join(out)

    @coerce
    def ljust(S, width, fillchar=None):
        """S.ljust(width[, fillchar]) -> int

        Return S left justified in a Unicode string of length width. Padding is
        done using the specified fill character (default is a space)."""
        if fillchar is None:
            fillchar = S.clone(u' ', S.reset_char)
        return S + fillchar * (width - len(S))

    @coerce
    def rjust(S, width, fillchar=None):
        """S.rjust(width[, fillchar]) -> colstr

        Return S right justified in a Unicode string of length width. Padding is
        done using the specified fill character (default is a space)."""
        if fillchar is None:
            fillchar = S.clone(u' ', S.reset_char)
        return fillchar * (width - len(S)) + S

    ######################
    ### TRANSFORMATION ###
    ######################

    # TODO: all of these functions should have a keepcolor flag that
    # defines what color the transformed bit should have (inherited from
    # the new piece or the part it's replacing).  This could be made an
    # attribute of the colstr() as a default behavior so that we can
    # avoid adding more non-str/unicode items to the interface.

    def reverse(S):
        """S.reverse(S) -> colstr"""
        return S.clone('').join(reversed(S))

    @coerce
    def translate(S, table):
        """S.translate(table) -> colstr

        Return a copy of the string S, where all characters have been mapped
        through the given translation table, which must be a mapping of
        Unicode ordinals to Unicode ordinals, Unicode strings or None.
        Unmapped characters are left untouched. Characters mapped to None
        are deleted."""

        # aaaand, this would ALMOST be simple, except the right-hand
        # side of the translate map for unicode objects can replace single
        # characters with multiple ones, which would stretch our colormap
        # in undefined ways.
        new = []
        for ch, col in zip(S.plain, S.colmap):
            o = ord(ch)
            if o in table:
                repl = table[o]
                if repl is None:
                    continue
                elif isinstance(repl, colstr):
                    ch, col = repl.plain, repl.colmap
                elif isinstance(repl, int):
                    ch = unichr(repl)
                else:
                    raise TypeError('character mapping must return integer, '
                                    'None or unicode')
            new.append(S.clone(ch, col))
        return S.clone('').join(new)

    def zfill(S, width):
        """S.zfill(width) -> colstr

        Pad a numeric string S with zeros on the left, to fill a field
        of the specified width. The string S is never truncated."""
        return S.rjust(width, '0')

    @coerce
    def replace(S, old, new, count=None, keepcolor=False):
        """S.replace (old, new[, count]) -> colstr

        Return a copy of S with all occurrences of substring
        old replaced by new.  If the optional argument count is
        given, only the first count occurrences are replaced.

        If keepcolor is True, the replaced bits will keep the same
        colormap as the parts they are replacing, albeit with undefined
        results if new and old are of different lengths.  The default
        (keepcolor=False) will cause the new pieces to have the color of
        the new object."""

        parts = []
        offset = len(old)
        S = S.clone()
        while S:
            if old not in S or count is not None and count == len(parts):
                break
            start = S.index(old)
            stop = start + offset
            if keepcolor:
                new = new.clone(None, S.colmap[start:stop])
            parts.append(S[:start] + new)
            S = S[stop:]
        parts.append(S)
        return S.clone('').join(parts)

    @coerce
    def __mod__(x, y, keepcolor=False):
        """x.__mod__(y) <==> x%y"""

        # i feel sorry for anyone who has to look at this piece of code :D
        # in essence, it cycles through sprintf format strings and
        # applies the replacement values individually.  the purpose of
        # this is to make sure the underly colormap is kept in tact.

        ytype = type(y)
        if ytype not in (dict, tuple):
            y = (y,)
            ytype = tuple
        parts = []
        if ytype is tuple:
            pos = 0
        x = x.clone()
        while x:
            match = x.fmt_re.search(x.plain)
            if not match:
                break
            start, stop = match.span()
            parts.append(x[:start])
            if match.group(5) == '%':
                parts.append('%')
            else:
                fmt = x[start:stop]
                if ytype is tuple:
                    val = y[pos]
                    pos += 1
                else:
                    mapkey = match.group(1)
                    val = y[mapkey]
                if isinstance(val, colstr):
                    plain, colmap = val.plain, val.colmap
                else:
                    plain, colmap = val, ''
                if keepcolor:
                    colmap = fmt.colmap
                if ytype is dict:
                    plain = {mapkey: plain}
                parts.append(x.clone(fmt.plain % plain, colmap))
            x = x[stop:]
        parts.append(x)
        return x.clone('').join(parts)

    def __rmod__(self, *args, **kwargs):
        """x.__rmod__(y) <==> y%x"""
        # XXX near as I can figure, this would only ever get called in a
        # modulo operation where the item on the LEFT did not have
        # __mod__ defined.. which in any conceivable context would
        # probably be integers, and I can't imagine what this object
        # would do in that case except explode, so:
        raise NotImplementedError

    def format(self, *args, **kwargs):
        """S.format(*args, **kwargs) -> colstr"""
        # XXX i'm not even sure what this does offhand, and it doesn't
        # have a docstring,  so i think it's safe to assume nothing in
        # my scripts will be needing it.. possibly a hook for the
        # new-style string formatting rules?
        raise NotImplementedError

