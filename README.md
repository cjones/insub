USAGE
=====

    $ ./insub.py <<<'"hi"|figlet|cow'
     ___________
    /  _     _  \
    | | |__ (_) |
    | | '_ \| | |
    | | | | | | |
    | |_| |_|_| |
    \           /
     -----------
            \   ^__^
             \  (oo)_______
                (__)       )/\
                    ||----w |
                    ||     ||

... it does a bit more than that, but that is the gist of it. For a list
of all the filters, run with -h


IRSSI
=====

irssi/insub.pl is a thin perl wrapper around the python script, which is
a total hack, but works. I am told irssi supports python embedding
natively, but it doesn't seem to in Ubuntu's repository, which is what I
use, so whatever. Use it like any other irssi module:

    $ cp -av irssi/insub.pl ~/.irssi/scripts/
    [irssi] /script load insub
