#!/usr/bin/perl -w

##############################################################################
# a suite of text filters to annoy people :D                                 #
#                                                                            #
# author: cj_ <cjones@gruntle.org>                                           #
#                                                                            #
# "If used sparingly, and in good taste, ASCII art generally                 #
# is very well-received !"                                                   #
#                             -- Some Sucker                                 #
#                                                                            #
# credits:                                                                   #
#    zb for adding ansi color support and putting this in ports :D           #
#    sisko for the original color script                                     #
#    various ideas from: tosat, jej, twid, cappy, rob                        #
#    uke for the inspiration for the checker                                 #
#    hlprmnky for the jigs and for debugging                                 #
#    various stolen things: emacs spook file, jwz's scrambler script         #
#                                                                            #
##############################################################################
# Copyright (c) 2003 Chris Jones <cjones@gruntle.org>                        #
#                                                                            #
# Redistribution and use in source and binary forms, with or without         #
# modification, are permitted provided that the following conditions         #
# are met:                                                                   #
#                                                                            #
# 1. Redistributions of source code must retain the above copyright          #
#    notice, this list of conditions and the following disclaimer.           #
# 2. Redistributions in binary form must reproduce the above copyright       #
#    notice, this list of conditions and the following disclaimer in the     #
#    documentation and/or other materials provided with the distribution.    #
#                                                                            #
# THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND    #
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE      #
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE #
# ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE   #
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL #
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS    #
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)      #
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT #
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY  #
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF     #
# SUCH DAMAGE.                                                               #
##############################################################################

use strict;
use vars qw($VERSION %IRSSI $SPLASH $NAME);
use Text::Wrap;
use IPC::Open3;


$NAME = "gay";
$VERSION = "8.5";

%IRSSI = (
	name		=> $NAME,
	version		=> $VERSION,
	author		=> 'cj_',
	contact		=> 'cjones@gruntle.org',
	download	=> 'http://gruntle.org/projects/irssi',
	description	=> 'a lot of annoying ascii color/art text filters',
	license		=> 'BSD',
);


##########################################
# Figure out where we are being run from #
# and set up the environment properly    #
##########################################

my $CONTEXT;	# [ irssi | terminal | cgi  ]
my $OUTPUT;	# [ irc   | ansi     | html ]

if ($ENV{"REQUEST_METHOD"}) {
	# cgi.. color routine should use
	# markup instead of ansi or mirc
	$CONTEXT = "cgi";
	$OUTPUT = "html";
} else {
	$OUTPUT = "irc";
	eval { Irssi::Core::is_static() };
	if ($@) {
		# this indicates that there is no irssi.. HENCE
		# we are being run from somewhere else.  do not use
		# Irssi extensions
		$CONTEXT = "terminal";
	} else {
		# no problems?  great.  preload Irssi functions
		$CONTEXT = "irssi";
		eval "use Irssi;";
	}
}

my $ansi_support = 0;
eval 'use Term::ANSIColor';
$ansi_support = 1 unless $@;


# being run from the command line, oh my.. use ANSI
# for color sequences instead of mirc
if ($CONTEXT eq "terminal" and -t STDIN) {
	$OUTPUT = 'ansi' if $ansi_support;
}

# some command names based on our root name
my $EXEC = $NAME . "exec";
my $CAT  = $NAME . "cat";

# Time::HiRes only works on some systems that support
# gettimeofday system calls.  safely test for this
my $can_throttle = 0;
eval "use Time::HiRes"; 
unless ($@) { $can_throttle = 1 }

# print function
sub cprint {
	my $text = shift;
	$text =~ s/\n//g;
	if ($CONTEXT eq "irssi") {
		Irssi::print($text);
	} else {
		print $text, "\n";
	}
}

# defaults
my $settings = {
	cowfile			=> "default",
	cowpath			=> undef,
	figfont			=> "standard",
	linewrap		=> 70,
	figlet_cmd		=> "figlet",
	rainbow_offset		=> 0,
	rainbow_keepstate	=> 1,
	keepstate_file		=> $ENV{HOME} . "/.$NAME-state",
	default_style		=> 1,
	check_size		=> 3,
	check_text		=> 0,
	check_colors		=> "4,2",
	matrix_size		=> 6,
	matrix_spacing		=> 2,
	colcat_max		=> 2048,
	jive_cmd		=> "jive",
	spook_words		=> 6,
	hug_size		=> 5,
};

# wrap settings routines.. irssi cares about type
# perl doesn't.. go figure

sub settings_get_str {
	my $key = shift;
	if ($CONTEXT eq 'irssi') {
		return Irssi::settings_get_str($key);
	} else {
		return $settings->{$key};
	}
}

sub settings_get_int {
	my $key = shift;
	if ($CONTEXT eq 'irssi') {
		return Irssi::settings_get_int($key);
	} else {
		return $settings->{$key};
	}
}

sub settings_get_bool {
	my $key = shift;
	if ($CONTEXT eq 'irssi') {
		return Irssi::settings_get_bool($key);
	} else {
		return $settings->{$key};
	}
}

sub settings_set_int {
	my $key = shift;
	my $val = shift;
	if ($CONTEXT eq 'irssi') {
		Irssi::settings_set_int($key, $val);
	} else {
		$settings->{$key} = $val;
	}
}

#######################
# define some globals #
#######################

# type of cow variable
my $thoughts;

# usage/contact info
$SPLASH = "$IRSSI{name} $IRSSI{version} by $IRSSI{author} <$IRSSI{contact}>";

my $USAGE;
if ($CONTEXT eq 'irssi' or $OUTPUT eq 'irc') {
	$USAGE = "/$NAME";
} elsif ($CONTEXT eq 'terminal' or $OUTPUT eq 'ansi') {
	$USAGE = $0;
}

$USAGE .= <<EOU;
 [filters|command] [text ...]
    commands: [usage|help|version|colors]
    filters:
         [-YES] [-msg nick] [-pre <nick>] [-spook] [-jive]
         [-scramble] [-leet] [-rev] [-matrix] [-fig]
         [-font <font>] [-hug] [-check|capchk] [-mirror]
         [-cow] [-cowfile <file>] [-flip] [-box|-3d|-arrow]
         [-123567] [-4[col]] [-blink] [-fake] [-ircii] [-jigs]
         [-throttle <milliseconds>] [-tree] [-think] [-unused]
EOU


my $blink = "\x1b[5m";

my $ansi_map = {
	0 => 'white',
	1 => 'black',
	2 => 'blue',
	3 => 'green',
	4 => 'bold red',
	5 => 'yellow',
	6 => 'magenta',
	7 => 'bold red',
	8 => 'bold yellow',
	9 => 'green',
	10 => 'cyan',
	11 => 'bold cyan',
	12 => 'bold blue',
	13 => 'bold magenta',
	14 => 'bold black',
	15 => 'bold white',
};

# This would probably be better as actual font attributes
# because we might want to use 'bold' or something.
# then we can just close with </font>
my $html_map = {
	0 => '#ffffff',
	1 => '#000000',
	2 => '#000088', # blue
	3 => '#00ff00',
	4 => '#880000',
	5 => '#ff5555',  # yellow?
	6 => '#ff00ff',
	7 => '#ff0000',
	8 => '#ff9999',  #bold yello?
	9 => '#008800',
	10 => '#004400', #cyan?
	11 => '#008800', #bold cyan?
	12 => '#0000ff', #bold blue',
	13 => '#ff00ff', #bold magenta',
	14 => '#333333', #bold black',
	15 => '#ffffff', #bold white',
};

my $has_color = 0;
sub do_color {
	my $text = shift;
	my $fg_col = shift;
	my $bg_col = shift;

	$has_color = 1;

	my $ret;
	if ($OUTPUT eq 'irc') {
		$ret = "\003$fg_col";

		if (defined $bg_col) {
			$ret .= ",$bg_col";
		}
		
		# if first char is a , or number,
		# we need some esc char's so the color thingy
		# doesn't get confused
		my $ord = ord(substr($text, 0, 1));
		if (($ord >= 48 and $ord <= 57) or $ord == 44) {
			$ret .= "\26\26";
		}

		return ($ret . $text . "\x03\26\26");
	} elsif ($OUTPUT eq 'ansi') {
		$ret = Term::ANSIColor::color($ansi_map->{$fg_col});

		# hack  :(
		if (defined $bg_col) {
			my $bg = $ansi_map->{$bg_col};
			$bg =~ s/bold //;
			$bg = "on_$bg";
			$ret .= Term::ANSIColor::color($bg);
		}

		$ret .= $text;
		$ret .= Term::ANSIColor::color("reset");

		return $ret;
	} elsif ($OUTPUT eq 'html') {
		$bg_col ||= 1; # default to black

		# this is the best place to do this, probably
		$text =~ s/</&lt;/g;
		$text =~ s/>/&gt;/g;

		if ($bg_col == 1) {
			# black is assumed because of a div taggy
			$ret = sprintf(
				qq(<span style="color:%s;">%s</span>),
				$html_map->{$fg_col},
				$text,
			);
		} else {
			$ret = sprintf(
				qq(<span style="color:%s;background-color:%s;">%s</span>),
				$html_map->{$fg_col},
				$html_map->{$bg_col},
				$text,
			);
		}

		return $ret;
	}


	return ($text);
}

sub show_colmap {
	foreach my $color (sort { $a <=> $b } keys %$ansi_map) {
		my $color_name = $ansi_map->{$color};
		my $msg = sprintf("%2d: %s\n", $color, $color_name);
		my $bg = ($color == 1) ? 0 : undef; # use white background for black
		cprint(do_color($msg, $color, $bg));
	}
}


# spook array.. in a perfect world this would
# be in its own file.  this is stolen right out of emacs,
# with some more modern stuff tacked on

my @spook_lines = (
	"\$400 million in gold bullion",
	"[Hello to all my fans in domestic surveillance]", "AK-47",
	"ammunition", "arrangements", "assassination", "BATF", "bomb", "CIA",
	"class struggle", "Clinton", "Cocaine", "colonel",
	"counter-intelligence", "cracking", "Croatian", "cryptographic",
	"Delta Force", "DES", "domestic disruption", "explosion", "FBI", "FSF",
	"fissionable", "Ft. Bragg", "Ft. Meade", "genetic", "Honduras",
	"jihad", "Kennedy", "KGB", "Khaddafi", "kibo", "Legion of Doom",
	"Marxist", "Mossad", "munitions", "Nazi", "Noriega", "North Korea",
	"NORAD", "NSA", "nuclear", "Ortega", "Panama", "Peking", "PLO",
	"plutonium", "Qaddafi", "quiche", "radar", "Rule Psix",
	"Saddam Hussein", "SDI", "SEAL Team 6", "security", "Semtex",
	"Serbian", "smuggle", "South Africa", "Soviet ", "spy", "strategic",
	"supercomputer", "terrorist", "Treasury", "Uzi", "Waco, Texas",
	"World Trade Center", "Liberals", "Cheney",

	# mine
	"Eggs", "Libya", "Bush", "Kill the president", "GOP", "Republican",
	"Shiite", "Muslim", "Chemical Ali", "Ashcroft", "Terrorism",
	"Al Qaeda", "Al Jazeera", "Hamas", "Israel", "Palestine", "Arabs",
	"Arafat", "Patriot Act", "Voter Fraud", "Punch-cards", "Diebold",
	"conspiracy", "Fallujah", "IndyMedia", "Skull and Bones", "Free Masons",
	"Kerry", "Grass Roots", "9-11", "Rocket Propelled Grenades",
	"Embedded Journalism", "Lockheed-Martin", "war profiteering", 


	# from blogs about the spooks
	"Kill the President", "anarchy", "echelon", "nuclear",
	"assassinate", "Roswell", "Waco", "World Trade Center", "Soros",
	"Whitewater", "Lebed", "HALO", "Spetznaz", "Al Amn al-Askari",
	"Glock 26", "Steak Knife", "Rewson", "SAFE", "Waihopai", "ASPIC",
	"MI6", "Information Security", "Information Warfare", "Privacy",
	"Information Terrorism", "Terrorism", "Defensive Information",
	"Defense Information Warfare", "Offensive Information",
	"Offensive Information Warfare", "Ortega Waco", "assasinate",
	"National Information Infrastructure", "InfoSec",
	"Computer Terrorism", "DefCon V", "Encryption", "Espionage", "NSA",
	"CIA", "FBI", "White House", "Undercover", "Compsec 97", "Europol",
	"Military Intelligence", "Verisign", "Echelon",
	"Ufologico Nazionale", "smuggle", "Bletchley Park", "Clandestine",
	"Counter Terrorism Security", "Enemy of the State", "20755-6000",
	"Electronic Surveillance", "Counterterrorism", "eavesdropping",
	"nailbomb", "Satellite imagery", "subversives", "World Domination",
	"wire transfer", "jihad", "fissionable", "Sayeret Mat'Kal",
	"HERF pipe-bomb", "2.3 Oz.  cocaine",
);

# leet mapping
my $leet_map = {
	a => [ "4", "/\\", "@", "a", "A" ],
	b => [ "|o", "b", "B" ],
	c => [ "C", "c", "<" ],
	d => [ "d", "D", "|)" ],
	e => [ "e", "E", "3" ],
	f => [ "f", "F", "/=" ],
	g => [ "g", "G", "6" ],
	h => [ "h", "H", "|-|" ],
	i => [ "i", "I", "|", "1" ],
	j => [ "j", "J" ],
	k => [ "keke", "x", "X", "k", "K", "|<" ],
	l => [ "l", "L", "7", "|_" ],
	m => [ "|V|", "|\\/|", "m", "M" ],
	n => [ "n", "N", "|\\|" ],
	o => [ "0", "o", "O", "()", "[]", "<>" ],
	p => [ "p", "P", "9" ],
	q => [ "q", "Q" ],
	r => [ "r", "R" ],
	s => [ "s", "S", "5" ],
	t => [ "t", "T", "7" ],
	u => [ "|_|", "u", "U", "\\/" ],
	v => [ "v", "V", "\\/" ],
	w => [ "w", "W", "uu", "UU", "uU", "Uu", "\\/\\/" ],
	x => [ "x", "X", "><" ],
	y => [ "y", "Y" ],
	z => [ "z", "Z", "5" ],
};

# 'jigs' mapping
my $jigs_map = {
	7	=> "8",
	8	=> "9",
	9	=> "0",
	0	=> "-",
	'-'	=> "=",
	'='	=> "7",
	y	=> "u",
	h	=> "j",
	n	=> "m",
	u	=> "i",
	j	=> "k",
	m	=> ".",
	i	=> "o",
	k	=> "l",
	","	=> ".",
	o	=> "p",
	l	=> ";",
	"."	=> "/",
	p	=> "[",
	";"	=> "'",
	"/"	=> "n",
	"["	=> "]",
	"]"	=> '\\',
	'"'	=> "h",
	'\\'	=> "u",
};


# random text for text substitution
# needless to say if someone has this string
# in their text, it'll get clobbered.
my $rnd = "rAnDoM";

# markup stuff
my $COWCUT = "---COWCUT---";

###############################
# these are the main commands #
###############################

sub insub {
	my $text = shift;

	if    ($text =~ /^(?:-YES )?help/i  ) { show_help()               }
	elsif ($text =~ /^(?:-YES )?vers/i  ) { cprint($SPLASH)           }
	elsif ($text =~ /^(?:-YES )?update/i) { update()                  }
	elsif ($text =~ /^(?:-YES )?usage/i ) { cprint_lines($USAGE)      }
	elsif ($text =~ /^(?:-YES )?col/i   ) { show_colmap()             }
	else                                  { process(undef, $text, @_) }
}

# these are aliases that use a predefined set of filters
sub colcow    { process("cr",  @_) }	# cowsay -> rainbow
sub insubexec { process("e",   @_) }    # execute
sub insubcat  { process("x",   @_) }	# byte restriction
sub gv        { process("v",   @_) }	# display version info

###############################
# this handles the processing #
###############################

sub process {
	my ($flags, $text, $server, $dest) = @_;

	$flags ||= ""; # silence undef warnings on cmd line

	
	if ($CONTEXT eq 'irssi') {
		if (!$server || !$server->{connected}) {
			cprint("Not connected to server");
			return;
		}

		return unless $dest;
	}



	# set up defaults
	my @text;
	my $prefix;
	my $style = settings_get_int("default_style");
	my $cowfile = settings_get_str("cowfile");
	my $figfont = settings_get_str("figfont");

	# extension to force color in alternating color style (4)
	# if left unset, it will perform randomly
	my $altcol;

	my $sendto = $dest->{name} if $dest;

	# parse args
	my @args;
	my $error_returned = 0;
	if ($text) {
		(@args, $error_returned) = shellwords($text);
		return if $error_returned;
	}

	my $throttle = 0;
	my $force = 0;
	while (my $arg = shift(@args)) {
		if ($arg =~ /^-msg/)      { $sendto = shift(@args); next }
		if ($arg =~ /^-pre/)      { $prefix = shift(@args); next }
		if ($arg =~ /^-blink/)    { $flags .= "b"; next }
		if ($arg =~ /^-jive/)     { $flags .= "j"; next }
		if ($arg =~ /^-cowfile/)  { $cowfile = shift(@args); next }
		if ($arg =~ /^-cow/)      { $flags .= "c"; next }
		if ($arg =~ /^-fig/)      { $flags .= "f"; next }
		if ($arg =~ /^-font/)     { $figfont = shift(@args); next }
		if ($arg =~ /^-box/)      { $flags .= "o"; next }
		if ($arg =~ /^-3d/)       { $flags .= "3"; next }
		if ($arg =~ /^-arrow/)    { $flags .= "a"; next }
		if ($arg =~ /^-check/)    { $flags .= "C"; next }
		if ($arg =~ /^-capchk/)   { $flags .= "h"; next }
		if ($arg =~ /^-matrix/)   { $flags .= "m"; next }
		if ($arg =~ /^-spook/)    { $flags .= "s"; next }
		if ($arg =~ /^-scramble/) { $flags .= "S"; next }
		if ($arg =~ /^-mirror/)   { $flags .= "M"; next }
		if ($arg =~ /^-rev/)      { $flags .= "R"; next }
		if ($arg =~ /^-leet/)     { $flags .= "l"; next }
		if ($arg =~ /^-hug/)      { $flags .= "H"; next }
		if ($arg =~ /^-flip/)     { $flags .= "F"; next }
		if ($arg =~ /^-fake/)     { $flags .= "I"; next }
		if ($arg =~ /^-ircii/)    { $flags .= "d"; next }
		if ($arg =~ /^-jigs/)     { $flags .= "J"; next }
		if ($arg =~ /^-tree/)     { $flags .= "t"; next }
		if ($arg =~ /^-think/)    { $flags .= "T"; next }
		if ($arg =~ /^-unused/)   { $flags .= "u"; next }
		if ($arg =~ /^-YES/)      { $force = 1; next    }
		if ($arg =~ /^-thro/)     { $throttle = shift(@args); next }

		# this is getting trickier
		if ($arg =~ /^-(\d+)$/) {
			$flags .= "r";
			$style = $1;
			next;
		} elsif ($arg =~ /^-4(\w+)$/) {
			$flags .= "r";
			$style = "4";
			$altcol = $1;
			next;
		}

		# doesn't match arguments, must be text!
		push(@text, $arg);
	}
	$text = join(" ", @text);
	$text =~ s/\\n/\n/sg;
	
	########################################
	# sanity check before applying filters #
	########################################
	
	if ($flags =~ /c/ and $flags =~ /T/) {
		cprint("This cow cannot THINK and SPEAK at the same time.");
		return;
	}

	if ($flags =~ /c/) { $thoughts = "\\" }
	if ($flags =~ /T/) { $thoughts = "o"  }
	
	# this stuff tries to protect you from yourself
	# .. using -YES will skip this
	unless ($force) {
		if ($flags =~ /h/ and $flags =~ /M/) {
			cprint("Combining -capchk and -mirror is bad, mkay (try -YES)");
			return;
		}

		if ($flags =~ /s/ and $flags =~ /f/) {
			cprint("Spook and figlet is probably a bad idea (see: -YES)");
			return;
		}

		if ((length($text) > 10) and $flags =~ /f/) {
			cprint("That's a lot of figlet.. use -YES if you are sure");
			return;
		}
	}

	# for outlining, precedence must be set
	# 3dbox > arrow > box
	$flags =~ s/(o|a)//g if $flags =~ /3/;
	$flags =~ s/o//g     if $flags =~ /a/;

	# check should override rainbow for now
	$flags =~ s/r//g if $flags =~ /C/;

	# ... so should capchk, unless it's a cow, in which case
	# we invoke cowcut-fu
	my $cowcut = 0;
	if ($flags =~ /h/) {
		# yes, capchk was specified
		if ($flags =~ /c/ and $flags =~ /r/) {
			$cowcut = 1;
		} else {
			$flags =~ s/r//g;
		}
	}

	# capchk takes precedence over check
	$flags =~ s/C//g if $flags =~ /h/;

	# the TREE cannot be colored
	$flags =~ s/r//g if $flags =~ /t/;

	if ($throttle) {
		unless ($can_throttle) {
			cprint("Sorry, your system does not allow high resolution sleeps");
			return;
		}

		if ($throttle < 10 or $throttle > 10_000) {
			cprint("Please use a throttle between 10ms and 10,000ms");
			return;
		}

		$throttle = $throttle / 1000;
	}


	##############################
	# filter text based on flags #
	##############################
	
	my $flag_list = "3CFHIJMRSTabcdefhjlmorstvxu";

	# flag sanity check.  because there are a lot of flags,
	# require master list to contain all viable flags
	if ($flag_list =~ /(.).*\1/) {
		cprint("There was an internal error with flag processing: duplicate ($1)");
		return;
	}

	foreach my $f (split(//, $flags)) {
		if ($flag_list !~ /$f/) {
			cprint("There was an internal error with flag processing: missing ($f)");
			return;
		}
	}

	# most useful command yet
	if ($flags =~ /u/) {
		cprint("Sorry, the -unused flag is unsupported.");
		return;
	}

	
	# where to get text
	$text = "$IRSSI{name} $IRSSI{version} - $IRSSI{download}/$IRSSI{name}" if $flags =~ /v/;
	$text = execute($text)           if $flags =~ /e/;
	$text = slurp($text)             if $flags =~ /x/;
	$text = spookify($text)          if $flags =~ /s/;

	# change the text contents itself
	$text = jive($text)              if $flags =~ /j/;
	$text = scramble($text)          if $flags =~ /S/;
	$text = leet($text)              if $flags =~ /l/;
	$text = reverse_ascii($text)     if $flags =~ /R/;
	$text = matrix($text)            if $flags =~ /m/;
	$text = jigs($text)              if $flags =~ /J/;

	# change the text appearance
	$text = figlet($text, $figfont)  if $flags =~ /f/;
	$text = hug($text)               if $flags =~ /H/;
	$text = gwrap($text)             if $flags !~ /f/;

	# change the text presentation
	$text = checker($text)                    if $flags =~ /h/;
	$text = reverse_ascii($text)              if $flags =~ /M/;
	$text = cowsay($text, $cowfile, $cowcut)  if $flags =~ /(c|T)/;
	$text = reverse_ascii($text)              if $flags =~ /M/ and $flags =~ /(c|T)/;
	$text = upside_down($text)                if $flags =~ /F/;
	$text = checker($text)                    if $flags =~ /C/;

	# draw a box, pass a style flag
	$text = outline($text, 0)                 if $flags =~ /o/;
	$text = outline($text, 1)                 if $flags =~ /3/;
	$text = outline($text, 2)                 if $flags =~ /a/;

	# change the final products visual appearance
	$text = rainbow($text, $style, $altcol)   if $flags =~ /r/;
	$text = tree($text)              if $flags =~ /t/;
	$text = blink($text)             if $flags =~ /b/;

	# stuff to bust ircii :D
	$text = ircii_fake($text) if $flags =~ /I/;
	$text = ircii_drop($text) if $flags =~ /d/;

	$text = prefix($text, $prefix) if $prefix;

	########################
	# output final product #
	########################

	# html needs to be handled with kids gloves
	if ($OUTPUT eq 'html') {
		print qq(<div style="background-color:black;color:white;"><pre>);
		
		# not colorized, we should look for
		# unescaped brackets ourselves,
		# since we can't reply on do_color() to handle
		# it.. this is ok since there won't be any html unless
		# it's from do_color
		unless ($has_color) {
			$text =~ s/</&lt;/g;
			$text =~ s/>/&gt;/g;
		}
	}


	foreach my $line (split(/\n/, $text)) {
		if ($CONTEXT eq 'irssi') {
			$server->command("msg $sendto $line");
		} elsif ($CONTEXT eq 'terminal' or $CONTEXT eq 'cgi') {
			print $line, "\n";
		}

		if ($throttle) {
			Time::HiRes::sleep($throttle);
		}
	}

	if ($OUTPUT eq 'html') {
		print qq(</pre></div>\n);
	}
}

###########
# FILTERS #
###########

sub prefix {
	my $text = shift || return;
	my $prefix = shift || return;

	my @new;
	foreach my $line (split(/\n/, $text)) {
		$line = "$prefix $line";
		push(@new, $line);
	}
	$text = join("\n", @new);

	return $text;
}

my $COWPATH;
sub find_cowpath {
	$COWPATH = $ENV{COWPATH} || "";
	return if -d $COWPATH;

	$COWPATH = settings_get_str("cowpath") || "";
	return if -d $COWPATH;

	my $cowsay_cmd = whereis("cowsay");
	if ($cowsay_cmd) {
		if (open(IN, "< $cowsay_cmd")) {
			while (my $line = <IN>) {
				if ($line =~ m!^\$cowpath = \$ENV\{'COWPATH'\} \|\| '(.*?)';!) {
					$COWPATH = $1;
					last;
				}
			}
			close IN;
		}
	}

	$COWPATH ||= "";

	return if -d $COWPATH;

	$COWPATH = undef;
	cprint("I could not figure out your COWPATH!!");
}

sub cowsay {
	# my cowsay implementation.. because normal cowsay
	# messes up bubble-size if you have imbedded
	# color codes.. this works pretty much the same,
	# except it doesn't have support for stuff like
	# tongue and eyes.
	
	my $text = shift;
	my $cowfile = shift || "default";
	my $cowcut = shift;

	# my mother tried to find my cowpath once.. once.
	unless ($COWPATH) { find_cowpath() }

	unless ($COWPATH) {
		cprint("I cannot continue with cowsay, for there is no COWPATH!");
		return $text;
	}

	my @output;

	# this is the whole point of doing my own cowsay
	my $length = 0;
	my @text = split(/\n/, $text);
	foreach my $line (@text) {
		my $l = clean_length($line);
		$length = $l if $l > $length;
	}

	# add filler to the end
	foreach my $line (@text) {
		$line .= (" " x ($length - clean_length($line)));
	}

	my $div = " " . ("-" x ($length+2));
	push(@output, $div);
	push(@output, $COWCUT) if $cowcut;
	my $count = 0;
	my $total = scalar(@text) - 1;
	foreach my $line (@text) {
		if ($total == 0) {
			push(@output, "< $line >");
		} elsif ($count == 0) {
			push(@output, "/ $line \\");
		} elsif ($count == $total) {
			push(@output, "\\ $line /");
		} else {
			push(@output, "| $line |");
		}
		$count++;
	}
	
	# this is rainbow() markup for toggling colorize
	push(@output, $COWCUT) if $cowcut;
	push(@output, $div);


	my $full;
	$cowfile .= ".cow" unless ($cowfile =~ /\.cow$/);
	if ($cowfile =~ m!/!) {
		$full = $cowfile;
	} else {
		foreach my $path (split(/:/, $COWPATH)) {
			if (-f "$path/$cowfile") {
				$full = "$path/$cowfile";
				last;
			}
		}
	}

	unless (-f $full) {
		cprint("could not find cowfile: $cowfile");
		return;
	}

	my $the_cow = "";
	my $eyes = "oo";
	my $tongue = "  ";

	# very odd.. unless $thoughts is addressed in some
	# fasion in this scope, eval doesn't notice it
	# i say this is a perl bug
	$thoughts = $thoughts;


	unless (open(IN, "<$full")) {
		cprint("couldn't read $full: $!");
		return;
	}
	my $cow_code = join('', <IN>);
	close IN;

	eval $cow_code;

	push(@output, split(/\n/, $the_cow));
	return join("\n", @output);
}

sub figlet {
	# pass text through figlet
	my $text = shift;
	my $figlet_font = shift || 'standard';
	my $figlet_wrap = settings_get_int('linewrap');

	# see if we can find the program
	my $figlet_cmd = settings_get_str('figlet_cmd');
	$figlet_cmd = -x $figlet_cmd ? $figlet_cmd : whereis("figlet");
	unless (-x $figlet_cmd) {
		cprint("$figlet_cmd not found or not executable!");
		return;
	}

	my $pid = open3(
		\*WRITE, \*READ, \*ERR,
		"$figlet_cmd -f $figlet_font -w $figlet_wrap"
	);

	print WRITE $text;
	close WRITE;

	$text = join('', <READ>);
	close READ;

	# check for errors
	cprint_lines(join('', <ERR>));
	close ERR;

	waitpid($pid, 0);

	$text =~ s/^\s+\n//g;     # sometime sit leaves leading blanks too!
	$text =~ s/\n\s+\n$//s;   # figlet leaves a trailing blank line.. sometimes

	return $text;
}

sub jive {
	# pass text through jive filter
	my $text = shift;

	# see if we can find the program
	my $jive_cmd = settings_get_str('jive_cmd');
	$jive_cmd = -x $jive_cmd ? $jive_cmd : whereis("jive");
	unless (-x $jive_cmd) {
		cprint("$jive_cmd not found or not executable!");
		return;
	}

	my $pid = open3(
		\*WRITE, \*READ, \*ERR,
		$jive_cmd
	);

	print WRITE $text;
	close WRITE;

	$text = join('', <READ>);
	close READ;

	# check for errors
	cprint_lines(join('', <ERR>));
	close ERR;

	waitpid($pid, 0);

	return $text;
}

sub checker {
	# checker filter.  thanks to uke
	my $text = shift;
	my $checksize = settings_get_int('check_size');
	my $checktext  = settings_get_int('check_text');

	my @colors = split(/\s*,\s*/, settings_get_str("check_colors"));

	my $rownum = 0;
	my $offset = 0;
	my @text = split(/\n/, $text);

	# what is the longest line?
	my $length = 0;
	foreach my $line (@text) {
		$length = length($line) if length($line) > $length;
	}

	foreach my $line (@text) {
		# pad line with whitespace
		$line .= (" " x ($length - length($line)));

		my $newline;
		my $state = 0;
		for (my $i = 0; $i < length($line); $i = $i + $checksize) {
			my $chunk = substr($line, $i, $checksize);
			my $index = ($state + $offset); $index -= scalar(@colors) if $index >= scalar(@colors);

			# add color
			$newline .= do_color($chunk, $checktext, $colors[$index]);
			$state++; $state = 0 if $state >= scalar(@colors);
		}

		$line = $newline;

		# increment rowcount/swap offset
		$rownum++;
		if ($rownum == $checksize) {
			$rownum = 0;
			$offset++; $offset = 0 if $offset >= scalar(@colors);
		}
	}
	return join("\n", @text);
}

sub get_state {
	my $state;
	if ($CONTEXT eq 'irssi') {
		$state = settings_get_int("rainbow_offset");
	} else {
		my $file = settings_get_str("keepstate_file");
		if (open(STATE, "< $file")) {
			$state = <STATE>;
			close STATE;
			chomp $state;
			$state =~ s/[^0-9]//g;
		}
	}

	$state ||= 0;
	return $state;
}

sub set_state {
	my $state = shift;
	if ($CONTEXT eq 'irssi') {
		settings_set_int("rainbow_offset", $state);
	} else {
		my $file = settings_get_str("keepstate_file");
		unlink($file);
		if (open(STATE, "> $file")) {
			print STATE "$state\n";
			close STATE;
		}
	}
}

sub rainbow {
	# make colorful text
	my ($text, $style, $altcol) = @_;

	# calculate stateful color offset
	my $state_offset = 0;
	if (settings_get_bool("rainbow_keepstate")) {
		$state_offset = get_state();
		if ($state_offset < 0 or $state_offset > 20) {
			$state_offset = 0;
		} else {
			$state_offset++;
		}

		set_state($state_offset);
	}
	
	# generate colormap based on style
	my @colormap;
	if ($style == 1) {
		# rainbow
		@colormap = (4,4,7,7,5,5,8,8,9,9,3,3,10,10,11,11,12,12,2,2,6,6,13,13);
	} elsif ($style == 2) {
		# patriotic
		@colormap = (4,4,0,0,12,12,4,4,0,0,12,12,4,4,0,0,12,12,4,4,0,0,12,12);
	} elsif ($style == 3) {
		# random colors
		while (scalar(@colormap) < 24) {
			my $color = int(rand(0) * 15) + 1;
			$color = 0 if $color == 1;
			push(@colormap, $color);
		}
	} elsif ($style == 4) {
		# alternating colors shade, color is random
		my $altcol_ind;

		if (defined $altcol) {
			if ($altcol =~ /blu/i) {
				$altcol_ind = 1;
			} elsif ($altcol =~ /gr(?:ee)?n/i) {
				$altcol_ind = 2;
			} elsif ($altcol =~ /(pur|vio|mag)/i) {
				$altcol_ind = 3;
			} elsif ($altcol =~ /gr[ae]?y/i) {
				$altcol_ind = 4;
			} elsif ($altcol =~ /yel/i) {
				$altcol_ind = 5;
			} elsif ($altcol =~ /red/i) {
				$altcol_ind = 6;
			}
		}

		unless (defined $altcol_ind && ($altcol_ind >= 1 and $altcol_ind <= 6)) {
			$altcol_ind = int(rand(0) * 6) + 1;
		}

		if ($altcol_ind == 1) {
			# blue
			@colormap = (2,12,2,12,2,12,2,12,2,12,2,12,2,12,2,12,2,12,2,12,2,12,2,12);
		} elsif ($altcol_ind == 2) {
			# green
			@colormap = (3,9,3,9,3,9,3,9,3,9,3,9,3,9,3,9,3,9,3,9,3,9,3,9);
		} elsif ($altcol_ind == 3) {
			# purple
			@colormap = (6,13,6,13,6,13,6,13,6,13,6,13,6,13,6,13,6,13,6,13,6,13,6,13);
		} elsif ($altcol_ind == 4) {
			# gray
			@colormap = (14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15);
		} elsif ($altcol_ind == 5) {
			# yellow
			@colormap = (7,8,7,8,7,8,7,8,7,8,7,8,7,8,7,8,7,8,7,8,7,8,7,8);
		} elsif ($altcol_ind == 6) {
			# red
			@colormap = (4,5,4,5,4,5,4,5,4,5,4,5,4,5,4,5,4,5,4,5,4,5,4,5);
		}
	} elsif ($style == 5) {
		# alternating shades of grey.  i liked this one so much i gave
		# it its own style.  does NOT like to blink, though
		@colormap = (14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15);
	} elsif ($style == 6) {
		# greyscale
		@colormap = (0,0,15,15,11,11,14,14,11,11,15,15,0,0,15,15,11,11,14,14,11,11,15,15);
	} elsif ($style == 7) {
		# christmas colors
		@colormap = (4,3,4,3,4,3,4,3,4,3,4,3,4,3,4,3,4,3,4,3,4,3,4,3);
	} else {
		# invalid style setting
		cprint("invalid style setting: $style");
		return;
	}

	# this gets toggle if cowcut markup is seen
	my $colorize = 1;

	# colorize.. thanks 2 sisko
	my $newtext;
	my $row = 0;
	foreach my $line (split(/\n/, $text)) {
		if ($line =~ /$COWCUT/) {
			# toggle state when we see this
			$colorize++;
			$colorize = 0 if $colorize == 2;
			next;
		}

		if ($colorize == 0) {
			$newtext .= "$line\n";
			next;
		}

		for (my $i = 0; $i < length($line); $i++) {
			my $chr = substr($line, $i, 1);
			my $color = $i + $row + $state_offset;
			$color = $color ?
				$colormap[$color %($#colormap-1)] :
				$colormap[0];
			if ($chr =~ /\s/) {
				$newtext .= $chr;
			} else {
				$newtext .= do_color($chr, $color);
			}
		}
		$newtext .= "\n";
		$row++;
	}

	return $newtext;
}

sub blink {
	# make the text blink
	my $text = shift;
	my @newtext;
	foreach my $line (split(/\n/, $text)) {
		if ($OUTPUT eq 'html') {
			push(@newtext, "<blink>$line</blink>");
		} else {
			push(@newtext, $blink . $line);
		}
	}
	return join("\n", @newtext);
}

sub clean_length {
	my $text = shift;
	$text =~ s/\x03\d+(,\d+)?(\26\26)?//g;
	$text =~ s/\x03\26\26//g;
	$text =~ s/\[\d+(?:,\d+)?m//g;
	$text =~ s/<span[^>]+>//g;
	$text =~ s/<\/span>//g;
	return length($text);
}

sub matrix {
	# 0-day greetz to EnCapSulaTE1!11!one
	my $text = shift;
	my $size = settings_get_int("matrix_size");
	my $spacing = settings_get_int("matrix_spacing");

	$size = 1 if ($size < 1);

	# first, let's dispense with the newlinesa
	# because they have no meaning up/down
	$text =~ s/\n/ /sg;

	my @text;
	for (my $i = 0; $i < length($text); $i += $size) {
		my $chunk = substr($text, $i, $size);
		for (my $j = 0; $j < length($chunk); $j++) {
			$text[$j] .= substr($chunk, $j, 1) . (" " x $spacing);
		}
	}
	return join("\n", @text);
}

sub outline {
	# draw a box around text.. thanks 2 twid
	# for the idea
	my ($text, $style) = @_;
	my ($_3d, $_arrow);

	if ($style == 1) {
		$_3d = 1;
	} elsif ($style == 2) {
		# arrow-style, thanks to rob
		$_arrow = 1;
	}
	
	my @text = split(/\n/, $text);

	# what is the longest line
	my $length = 0;
	
	foreach my $line (@text) {
		$length = clean_length($line) if clean_length($line) > $length;
	}

	# add box around each line
	my $lc = "|"; my $rc = "|";
	if ($_arrow) { $lc = ">"; $rc = "<" }
	foreach my $line (@text) {
		$line = "$lc $line" . (" " x ($length - clean_length($line) + 1)) . "$rc";
		$line .= " |" if ($_3d);
	}

	# top/bottom frame
	my ($top_frame, $bottom_frame);
	if ($_arrow) {
		$top_frame = "\\" . ("^" x ($length + 2)) . "/";
		$bottom_frame = "/" . ("^" x ($length + 2)) . "\\";
	} else {
		$top_frame = "+" . ("-" x ($length + 2)) . "+";
		$bottom_frame = $top_frame;
	}


	if ($_3d) {
		push(@text, $bottom_frame . "/");
		unshift(@text, $top_frame . " |");
	} else {
		push(@text, $bottom_frame);
		unshift(@text, $top_frame);
	}

	if ($_3d) {
		unshift(@text, " /" . (" " x ($length + 2)) . "/|");
		unshift(@text, "  " . ("_" x ($length + 3)));
	}


	return join("\n", @text);
}

sub whereis {
	# evaluate $PATH, since this doesn't seem to be inherited
	# in sh subproccess in irssi.. odd
	my $cmd = shift;
	my $path;
	
	# generate a lot of possible locations for cowsay path
	$path .= $ENV{PATH};
	$path .= ":/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin";
	$path .= ":/usr/local/cowsay/bin:/opt/cowsay/bin";

	foreach my $path (split(/:/, $path)) {
		next unless $path;
		if (-x "$path/$cmd") {
			return "$path/$cmd";
		}
	}
}

sub slurp {
	# read in a file with max setting (useful for catting /dev/urandom :D )
	# maybe make this read in chunks, not by line, or something.. seems clumsy
	my $file = shift;

	# expand ~
	$file =~ s!^~([^/]*)!$1 ? (getpwnam($1))[7] : ($ENV{HOME} || $ENV{LOGDIR} || (getpwuid($>))[7])!ex;

	unless (open(IN, "<$file")) {
		cprint("could not open $file: $!");
		return;
	}

	my $max = settings_get_int("colcat_max");
	my $text;
	while (my $line = <IN>) {
		$text .= $line;
		last if length($text) >= $max;
	}
	close IN;

	return $text;
}

sub execute {
	# execute command and return output
	my $text = shift;

	my $pid = open3(
		\*WRITE, \*READ, \*ERR,
		$text
	);

	close WRITE;

	$text = join('', <READ>);
	close READ;
	
	# check for errors
	cprint_lines(join('', <ERR>));
	close ERR;

	waitpid($pid, 0);

	return $text;
}



sub show_help {
	my $help = <<EOH;
$USAGE

STYLES:
-1     rainbow
-2     red white and blue
-3     random colors
-4     random alternating colors
-5     alternating gray
-6     greyscale
-7     festive

IRC ONLY:
/$NAME          just like /say, but takes args
/$EXEC      like /exec
/$CAT       pipe a file
/gv           say version outloud

SETTINGS:
   cowfile
   cowpath
   figfont
   linewrap
   figlet_cmd
   rainbow_offset
   rainbow_keepstate
   default_style
   check_size
   check_text
   check_colors
   matrix_size
   matrix_spacing
   colcat_max
   jive_cmd
   spook_words
   hug_size
EOH
	cprint_lines(draw_box($SPLASH, $help, undef, 1));
}

sub draw_box {
	# taken from a busted script distributed with irssi
	# just a simple ascii line-art around help text
	my ($title, $text, $footer, $color) = @_;

	$color = 0 unless $CONTEXT eq 'irssi';

	$footer = $title unless($footer);
	my $box;
	$box .= '%R,--[%n%9%U' . $title . '%U%9%R]%n' . "\n";
	foreach my $line (split(/\n/, $text)) {
		$box .= '%R|%n ' . $line . "\n";
	}
	$box .= '%R`--<%n' . $footer . '%R>->%n';
	$box =~ s/%.//g unless $color;
	return $box;
}

sub cprint_lines {
	my $text = shift;
	foreach my $line (split(/\n/, $text)) {
		cprint("$line\n");
	}
}

sub update {
	unless ($CONTEXT eq 'irssi') {
		warn "let's not do that outside irssi ok?\n";
		return;
	}

	# automatically check for updates
	my $baseURL = $IRSSI{download} . "/" . $IRSSI{name};
	
	# do we have useragent?
	eval "use LWP::UserAgent";
	if ($@) {
		cprint("LWP::UserAgent failed to load: $!");
		return;
	}

	# first see what the latest version is
	my $ua = LWP::UserAgent->new();
	$ua->agent("$IRSSI{name}-$IRSSI{version} updater");
	my $req = HTTP::Request->new(GET => "$baseURL/CURRENT");
	my $res = $ua->request($req);
	if (!$res->is_success()) {
		cprint("Problem contacting the mothership: " . $res->status_line());
		return;
	}

	my $latest_version = $res->content(); chomp $latest_version;
	cprint("Your version is: $VERSION");
	cprint("Current version is: $latest_version");

	if ($VERSION >= $latest_version) {
		cprint("You are up to date");
		return;
	}

	# uh oh, old stuff!  time to update
	cprint("You are out of date, fetching latest");
	$req = HTTP::Request->new(GET => "$baseURL/$IRSSI{name}-$latest_version.pl");

	my $script_dir = Irssi::get_irssi_dir() . "/scripts";
	my $saveTo = "$script_dir/downloaded-$IRSSI{name}.pl";
	$res = $ua->request($req, $saveTo);
	if (!$res->is_success()) {
		cprint("Problem contacting the mothership: " . $res->status_line());
		return;
	}

	# copy to location
	rename($saveTo, "$script_dir/$IRSSI{name}.pl");

	cprint("Updated successfully! '/run $IRSSI{name}' to load");
}


sub spookify {
	# add emacs spook text.  if there is previously existing text, it appends
	my $text = shift;
	my $count = settings_get_int('spook_words') || return $text;
	my @spook_words;
	for (my $i = 0; $i < $count; $i++) {
		my $word = $spook_lines[int(rand(0) * scalar(@spook_lines))];
		push(@spook_words, $word);
	}
	$text = join(" ", @spook_words) . " $text";
	return $text;
}

sub gwrap {
	# fix that shit
	my $text = shift;
	my $wrap = settings_get_int("linewrap") || return $text;
	$Text::Wrap::columns = $wrap;
	my @output;
	foreach my $line (split(/\n/, $text)) {
		local $^W = undef; # silence spurious warnings
		if (length($line) > $wrap) {
			($line) = Text::Wrap::wrap(undef, undef, $line);
		}
		$line =~ s/\t/     /g;
		push(@output, $line);
	}

	$text = join("\n", @output);
	return $text;
}

sub leet {
	# leet speak :(
	my $text = shift;
	my @output;
	foreach my $line (split(/\n/, $text)) {
		my $newline;
		for (my $i = 0; $i < length($line); $i++) {
			my $char = lc(substr($line, $i, 1));
			if ($leet_map->{$char}) {
				my @possibles = @{$leet_map->{$char}};
				$char = $possibles[int(rand(0) * scalar(@possibles))];
			}
			$newline .= $char;
		}
		push(@output, $newline);
	}
	return join("\n", @output);
}

sub hug {
	my $text = shift;
	my @text = split(/\n/, $text);
	my $size = settings_get_int("hug_size");

	# what is the longest line
	my $length = 0;
	foreach my $line (@text) {
		$length = clean_length($line) if clean_length($line) > $length;
	}


	my @output;
	foreach my $line (@text) {
		$line = ("{" x $size) . ' ' . $line . (' ' x ($length - length($line))) . ' ' . ("}" x $size);
		push(@output, $line);
	}

	return join("\n", @output);
}

sub reverse_ascii {
	#####################
	# reverse ascii art #
	#####################
	
	my $text = shift;
	my @lines = split(/\n/, $text);

	# how big is the longest line
	my $length = 0;
	foreach my $line (@lines) {
		my $line_length = clean_length($line);
		$length = $line_length if ($line_length > $length);
	}

	my @output;
	foreach my $line (@lines) {
		if ($line =~ /$COWCUT/) {
			push(@output, $line);
		} else {
			$line =~ s!/!$rnd!g;  $line =~ s!\\!/!g; $line =~ s!$rnd!\\!g;
			$line =~ s!{!$rnd!g;  $line =~ s!}!{!g;  $line =~ s!$rnd!}!g;
			$line =~ s!\(!$rnd!g; $line =~ s!\)!(!g; $line =~ s!$rnd!)!g;
			$line =~ s!\[!$rnd!g; $line =~ s!\]![!g; $line =~ s!$rnd!]!g;
			$line =~ s!<!$rnd!g;  $line =~ s!>!<!g;  $line =~ s!$rnd!>!g;
			push(@output, sprintf("%" . $length . "s", scalar(reverse($line))));
		}
	}

	return join("\n", @output);
}

sub upside_down {
	# kind of like reverse_ascii, only on a different axis
	my $text = shift;
	my @output;
	foreach my $line (split(/\n/, $text)) {
		$line =~ s!/!$rnd!g;  $line =~ s!\\!/!g; $line =~ s!$rnd!\\!g;
		$line =~ s!v!$rnd!g;  $line =~ s!\^!v!g; $line =~ s!$rnd!^!g;
		$line =~ s!w!$rnd!g;  $line =~ s!m!w!g;  $line =~ s!$rnd!m!g;
		$line =~ s!_!-!g;
		unshift(@output, $line);
	}

	return join("\n", @output);
}

# irssi is not friendly to require semantic
# so just use perl's shellwords.pl here
sub shellwords {
	my $text = join('', @_) if @_;
	my (@words, $snippet, $field);

	$text =~ s/^\s+//;

	# fix deep recursion case (can't escape newline :P)
	# found by hlprmnky
	if ($text =~ /(?:[^\\]|^)\x5c$/) {
		cprint("Unmatched escape");
		return;
	}

	while ($text ne '') {
		$field = '';
		for (;;) {
			if ($text =~ s/^"(([^"\\]|\\.)*)"//) {
				($snippet = $1) =~ s#\\(.)#$1#g;
			} elsif ($text =~ /^"/) {
				cprint("Unmatched double quote");
				return;
			} elsif ($text =~ s/^'(([^'\\]|\\.)*)'//) {
				($snippet = $1) =~ s#\\(.)#$1#g;
			} elsif ($text =~ /^'/) {
				cprint("Unmatched single quote");
				return;
			} elsif ($text =~ s/^\\(.)//) {
				$snippet = $1;
			} elsif ($text =~ s/^([^\s\\'"]+)//) {
				$snippet = $1;
			} else {
				$text =~ s/^\s+//;
				last;
			}

			$field .= $snippet;
		}
		push(@words, $field);
	}
	return @words;
}

sub scramble {
	# stupid blog meme about mixing up
	# the inside letters
	my $text = shift;
	my @newtext;
	foreach my $line (split(/\n/, $text)) {
		my @newline;
		foreach my $word (split(/\s+/, $line)) {
			my @letters = split(//, $word);
			my $first = shift(@letters);
			my $last = pop(@letters);
			fisher_yates_shuffle(\@letters) if scalar(@letters) > 0;
			my $newline = $first . join('', @letters) . $last;
			push(@newline, $newline);
		}
		push(@newtext, join(" ", @newline));
	}

	$text = join("\n", @newtext);
	return $text;
}

sub fisher_yates_shuffle {
	# safe randomizing
	my $array = shift;
	my $i;
	for ($i = @$array; --$i; ) {
		my $j = int rand ($i+1);
		next if $i == $j;
		@$array[$i,$j] = @$array[$j,$i];
	}
}

sub ircii_fake {
	# some ansi stuff to obscure the <nick>
	
	my $text = shift;
	my @new;

	foreach my $line (split(/\n/, $text)) {
		$line = "\x85\x8d$line";
		push(@new, $line);
	}

	$text = join("\n", @new);

	return $text;
}

sub ircii_drop {
	# this is just evil.  move the cursor somewhere
	# inconvenient
	
	my $text = shift;
	my $evil = "\x84" x 23;

	return "$evil$text";
}

# shift ascii homerow, code by hlprmnky
# hella copped from leet, above
sub jigs {
	my $text = shift;
	my @output;
	foreach my $line (split(/\n/, $text)) {
		my $newline;
		for (my $i = 0; $i < length($line); $i++) {
			my $char = lc(substr($line, $i, 1));
			if ($jigs_map->{$char}) {
				$char = $jigs_map->{$char};
			}
			$newline .= $char;
		}
		push(@output, $newline);
	}
	return join("\n", @output);
}

#######################
### christmas stuff ###
#######################

sub tree {
	# this is the hardest filter i've ever written :(
	# there must be a more graceful, or at least ideomatic,
	# way of doing this, but i can't think of it.
	#
	# TODO allow for density specs.. this will complicate
	# it even more, because i'll have to hit each line
	# in chunks
	
        my $text = shift;
	return unless $text;

	# bulbs.. only bright primary colors
        my @bulbs = (2,4,6,8,12);

	# don't do this in the loop or you don't get
	# random numbers
	srand(time());

	# cache green
	my $green = 3;

	my @output;
        foreach my $line (split(/\n/, $text)) {
		# it's gotta be at least 3 chars long to work
		unless (length($line) > 2) {
			push(@output, $line);
			next;
		}

		# the inside can't be all whitespace
		if ($line =~ /^.\s+.$/) {
			push(@output, $line);
			next;
		}

		# split line into an array of characters
		my @row = split(//, $line);

		# determine which points can be changed
		my @map;
		for (my $i = 0; $i < scalar(@row); $i++) {
			my $char = $row[$i];

			if ($i == 0 or $i == $#row) {
				push(@map, 0);
			} elsif ($char =~ /\s/) {
				push(@map, 0);
			} else {
				push(@map, 1);
			}
		}

		# (int(rand(0) * (max - min + 1))) + min
		my $max = grep(($_ == 1), @map);
		my $min = 1;
		my $map_pos = (int(rand(0) * ($max - $min + 1))) + $min;


		# god this is such a hack...
		# figure out which part of @map we mean
		my $count = 0;
		my $actual;
		for (my $i = 0; $i < scalar(@map); $i++) {
			my $map = $map[$i];

			if ($map == 1) {
				$count++;
			}

			if ($count == $map_pos) {
				$actual = $i;
				last;
			}
		}


		my ($head, $bulb, $foot);
		my $switch = 0;
		for (my $i = 0; $i < scalar(@row); $i++) {
			if ($i == $actual) {
				my $color = $bulbs[rand(@bulbs)];
				$bulb = do_color("*", $color);
				$switch++;
			} elsif ($switch == 0) {
				$head .= $row[$i];
			} elsif ($switch == 1) {
				$foot .= $row[$i];
			}
		}

		my $newline = do_color($head, $green) . $bulb . do_color($foot, $green);
		push(@output, $newline);
        }

	$text = join("\n", @output);
        return $text;
}

if ($CONTEXT eq 'terminal') {
	my @args;
	while (my $arg = shift(@ARGV)) {
		if ($arg =~ /^-html/o) { $OUTPUT = 'html'; next }
		if ($arg =~ /^-ansi/o) { $OUTPUT = 'ansi' if $ansi_support; next }
		push(@args, $arg);
	}

	if (@args) {
		insub(join(" ", @args));
	} else {
		print $USAGE, "\n";
	}

	exit(0);
} elsif ($CONTEXT eq 'cgi') {
	eval "use CGI";
	if ($@) {
		print "error: CGI module unloadable.\n";
		exit 1;
	}

	print CGI::header(), qq(<html><body text="white" bgcolor="black">\n);

	insub(CGI::param("args"));

	print "</body></html>\n";

	exit 0;
} elsif ($CONTEXT eq 'irssi') {
	# command bindings.. basically there
	# is only one "real" command, the rest
	# are aliases for preset filters. so,
	# only do this if we are in Irssi
	Irssi::command_bind($NAME, \&insub);
	Irssi::command_bind("colcow", \&colcow);
	Irssi::command_bind($EXEC, \&insubexec);
	Irssi::command_bind($CAT, \&insubcat);
	Irssi::command_bind("gv", \&gv);


	# if run in Irssi, establish settings and
	# provide default values

	# cowsay
	Irssi::settings_add_str($IRSSI{name}, 'cowfile', $settings->{cowfile});
	Irssi::settings_add_str($IRSSI{name}, 'cowpath', $settings->{cowpath});

	# figlet
	Irssi::settings_add_str($IRSSI{name}, 'figfont', $settings->{figfont});
	Irssi::settings_add_int($IRSSI{name}, 'linewrap', $settings->{linewrap});
	Irssi::settings_add_str($IRSSI{name}, 'figlet_cmd', $settings->{figlet_cmd});

	# rainbow
	Irssi::settings_add_int($IRSSI{name}, 'rainbow_offset', $settings->{rainbow_offset});
	Irssi::settings_add_bool($IRSSI{name}, 'rainbow_keepstate', $settings->{rainbowkeepstate});
	Irssi::settings_add_int($IRSSI{name}, 'default_style', $settings->{default_style});

	# checkers
	Irssi::settings_add_int($IRSSI{name}, 'check_size', $settings->{check_size});
	Irssi::settings_add_int($IRSSI{name}, 'check_text', $settings->{check_text});
	Irssi::settings_add_str($IRSSI{name}, 'check_colors', $settings->{check_colors});

	# the matrix
	Irssi::settings_add_int($IRSSI{name}, 'matrix_size', $settings->{matrix_size});
	Irssi::settings_add_int($IRSSI{name}, 'matrix_spacing', $settings->{matrix_spacing});

	# misc
	Irssi::settings_add_int($IRSSI{name}, 'colcat_max', $settings->{colcat_max});
	Irssi::settings_add_str($IRSSI{name}, 'jive_cmd', $settings->{jive_cmd});
	Irssi::settings_add_int($IRSSI{name}, 'spook_words', $settings->{spook_words});
	Irssi::settings_add_int($IRSSI{name}, 'hug_size', $settings->{hug_size});

	cprint("$SPLASH.  '/$NAME help' for usage");
}


