############################################################################
# a lot of gay text filters to annoy everyone (HOLLA to #insub :D)         #
#                                                                          #
# author: cj_ <cjones@gruntle.org>                                         #
# type /gay help for usage after loading                                   #
#                                                                          #
# "If used sparingly, and in good taste, ASCII art generally               #
# is very well-received !"                                                 #
#                             -- Some Sucker                               #
#                                                                          #
############################################################################
#   This program is free software; you can redistribute it and/or modify   #
#   it under the terms of the GNU General Public License as published by   #
#   the Free Software Foundation; version 2 dated June, 1991.              #
#                                                                          #
#   This program is distributed in the hope that it will be useful,        #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of         #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          #
#   GNU General Public License for more details.                           #
#                                                                          #
#   You should have received a copy of the GNU General Public License      #
#   along with this program; if not, write to the Free Software            #
#   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA              #
#   02111-1307, USA.                                                       #
############################################################################

use Irssi;
use Text::Wrap;
use strict;
use vars qw($VERSION %IRSSI $SPLASH);

$VERSION = "6.2";
%IRSSI = (
	author		=> 'cj_',
	contact		=> 'cjones@gruntle.org',
	download	=> 'http://gruntle.org/projects/irssi',
	name		=> 'gay',
	description	=> 'a lot of annoying ascii color/art text filters',
	license		=> 'GPLv2',
	version		=> $VERSION,
);

#######################
# define some globals #
#######################

# usage/contact info
$SPLASH = "$IRSSI{name} $IRSSI{version} by $IRSSI{author} <$IRSSI{contact}>";

# quick help
my $USAGE = <<EOU;
/COMMAND [-YES] [-msg nick] [-pre <nick>] [-spook] [-jive]
         [-scramble] [-leet] [-rev] [-matrix] [-fig]
         [-font <font>] [-hug] [-check|capchk] [-mirror]
         [-cow] [-cowfile <file>] [-flip] [-box|-3d|-arrow]
         [-123456] [-blink] [-fake] [-ircii] [-jigs] <text ...>
EOU

# for /gay col, list colormap
my $COLMAP = <<COLMAP;
0,1\26\26 0 = white
1,0\26\26 1 = black
2,1\26\26 2 = blue
3,1\26\26 3 = green
4,1\26\26 4 = orange
5,1\26\26 5 = red (yellow in epic/bx)
6,1\26\26 6 = magenta
7,1\26\26 7 = yellow (red in epic/bx)
8,1\26\26 8 = bright yellow
9,1\26\26 9 = bright green
10,1\26\26 10 = cyan
11,1\26\26 11 = gray
12,1\26\26 12 = bright blue
13,1\26\26 13 = bright purple
14,1\26\26 14 = dark gray
15,1\26\26 15 = light gray
COLMAP

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
	"World Trade Center",

	# mine
	"Eggs", "Libya", "Bush", "Kill the president", "GOP", "Republican",
	"Shiite", "Muslim", "Chemical Ali", "Ashcroft", "Terrorism",
	"Al Qaeda", "Al Jazeera", "Hamas", "Israel", "Palestine", "Arabs",
	"Arafat", "Patriot Act", "Voter Fraud", "Punch-cards",

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


# handler to reap dead children
# need this to avoid zombie/defunt processes
# waiting around to have their exit status read
my $child_pid;  
sub sigchild_handler {
	waitpid($child_pid, 0);
}

# declar this a global to prevent gay.pl
# from constantly checking
my $cowpath;

# markup stuff
my $COWCUT = "---COWCUT---";

###############################
# these are the main commands #
###############################

sub gay {
	my $text = shift;

	if    ($text =~ /^(?:-YES )?help/i  ) { show_help()           }
	elsif ($text =~ /^(?:-YES )?vers/i  ) { Irssi::print($SPLASH) }
	elsif ($text =~ /^(?:-YES )?update/i) { update()              }
	elsif ($text =~ /^(?:-YES )?usage/i ) { show_error($USAGE)    }
	elsif ($text =~ /^(?:-YES )?col/i   ) { show_error($COLMAP)   }
	else                                  { process(undef, $text, @_) }
}

# these are aliases that use a predefined set of filters
sub colcow    { process("cr",  @_) }	# cowsay -> rainbow
sub gayexec   { process("e",   @_) }    # execute
sub gaycat    { process("x",   @_) }	# gaycat w/ byte restriction
sub gv        { process("v",   @_) }	# display version info

###############################
# this handles the processing #
###############################

sub process {
	my ($flags, $text, $server, $dest) = @_;

	if (!$server || !$server->{connected}) {
		Irssi::print("Not connected to server");
		return;
	}

	return unless $dest;

	# set up defaults
	my @text;
	my $prefix;
	my $style = Irssi::settings_get_int("gay_default_style");
	my $cowfile = Irssi::settings_get_str("cowfile");
	my $figfont = Irssi::settings_get_str("figfont");
	my $sendto = $dest->{name};

	# parse args
	my @args;
	my $error_returned = 0;
	if ($text) {
		(@args, $error_returned) = shellwords($text);
		return if $error_returned;
	}

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
		if ($arg =~ /^-YES/)      { $force = 1; next    }
		if ($arg =~ /^-(\d)$/)    { $flags .= "r"; $style = $1; next }

		# doesn't match arguments, must be text!
		push(@text, $arg);
	}
	$text = join(" ", @text);
	$text =~ s/\\n/\n/sg;
	
	########################################
	# sanity check before applying filters #
	########################################
	
	# this stuff tries to protect you from yourself
	# .. using -YES will skip this
	unless ($force) {
		if ($flags =~ /h/ and $flags =~ /M/) {
			Irssi::print("Combining -capchk and -mirror is bad, mkay (try -YES)");
			return;
		}

		if ($flags =~ /s/ and $flags =~ /f/) {
			Irssi::print("Spook and figlet is probably a bad idea (see: -YES)");
			return;
		}

		if ((length($text) > 10) and $flags =~ /f/) {
			Irssi::print("That's a lot of figlet.. use -YES if you are sure");
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


	##############################
	# filter text based on flags #
	##############################
	
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
	$text = wrap($text)              if $flags !~ /f/;

	# change the text presentation
	$text = checker($text)                    if $flags =~ /h/;
	$text = reverse_ascii($text)              if $flags =~ /M/;
	$text = cowsay($text, $cowfile, $cowcut)  if $flags =~ /c/;
	$text = reverse_ascii($text)              if $flags =~ /M/ and $flags =~ /c/;
	$text = upside_down($text)                if $flags =~ /F/;
	$text = checker($text)                    if $flags =~ /C/;

	# draw a box, pass a style flag
	$text = outline($text, 0)                 if $flags =~ /o/;
	$text = outline($text, 1)                 if $flags =~ /3/;
	$text = outline($text, 2)                 if $flags =~ /a/;

	# change the final products visual appearance
	$text = rainbow($text, $style)   if $flags =~ /r/;
	$text = blink($text)             if $flags =~ /b/;

	# stuff to bust ircii :D
	$text = ircii_fake($text) if $flags =~ /I/;
	$text = ircii_drop($text) if $flags =~ /d/;

	########################
	# output final product #
	########################

	foreach my $line (split(/\n/, $text)) {
		$line = "$prefix $line" if ($prefix);
		$server->command("msg $sendto $line");
	}
}

######################################################
# these filters pass text through various gayalizers #
######################################################

sub find_cowpath {
	# see if we can find the program
	my $cowsay_cmd = Irssi::settings_get_str('cowsay_cmd');
	$cowsay_cmd = -x $cowsay_cmd ? $cowsay_cmd : whereis("cowsay");
	unless (-x $cowsay_cmd) {
		Irssi::print("$cowsay_cmd not found or not executable!");
		return;
	}

	unless (open(COWSAY, "<$cowsay_cmd")) {
		Irssi::print("problem reading $cowsay_cmd");
		return;
	}

	my $find_cowpath;
	while (my $line = <COWSAY>) {
		if ($line =~ m!^\$cowpath = \$ENV\{'COWPATH'\} \|\| '(.*?)';!) {
			$find_cowpath = $1;
			last;
		}
	}

	close COWSAY;

	if (!$find_cowpath) { Irssi::print("I was unable to find the cowpath!") }
	return $find_cowpath;
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
	if (!$cowpath) { $cowpath = $ENV{COWPATH} || find_cowpath() }

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
		foreach my $path (split(/:/, $cowpath)) {
			if (-f "$path/$cowfile") {
				$full = "$path/$cowfile";
				last;
			}
		}
	}

	unless (-f $full) {
		Irssi::print("could not find cowfile: $cowfile");
		return;
	}

	my $the_cow = "";
	my $thoughts = '\\';
	my $eyes = "oo";
	my $tongue = "  ";


	unless (open(IN, "<$full")) {
		Irssi::print("couldn't read $full: $!");
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
	my $figlet_wrap = Irssi::settings_get_int('linewrap');

	# see if we can find the program
	my $figlet_cmd = Irssi::settings_get_str('figlet_cmd');
	$figlet_cmd = -x $figlet_cmd ? $figlet_cmd : whereis("figlet");
	unless (-x $figlet_cmd) {
		Irssi::print("$figlet_cmd not found or not executable!");
		return;
	}

	open3(*READ, *WRITE, *ERR, "$figlet_cmd -f $figlet_font -w $figlet_wrap");
	print WRITE $text;
	close WRITE;

	$text = join('', <READ>);
	close READ;

	# check for errors
	show_error(join('', <ERR>));
	close ERR;

	$text =~ s/^\s+\n//g;     # sometime sit leaves leading blanks too!
	$text =~ s/\n\s+\n$//s;   # figlet leaves a trailing blank line.. sometimes

	return $text;
}

sub jive {
	# pass text through jive filter
	my $text = shift;

	# see if we can find the program
	my $jive_cmd = Irssi::settings_get_str('jive_cmd');
	$jive_cmd = -x $jive_cmd ? $jive_cmd : whereis("jive");
	unless (-x $jive_cmd) {
		Irssi::print("$jive_cmd not found or not executable!");
		return;
	}

	open3(*READ, *WRITE, *ERR, "$jive_cmd");
	print WRITE $text;
	close WRITE;

	$text = join('', <READ>);
	close READ;

	# check for errors
	show_error(join('', <ERR>));
	close ERR;

	return $text;
}

sub checker {
	# checker filter.  thanks to uke, my gay competition
	my $text = shift;
	my $checksize = Irssi::settings_get_int('check_size');
	my $checktext  = Irssi::settings_get_int('check_text');

	my @colors = split(/\s*,\s*/, Irssi::settings_get_str("check_colors"));

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

			# figure out color code
			my $code = "\x03" . $checktext . "," . $colors[$index] . "\26\26";

			$newline .= "$code$chunk";
			$state++; $state = 0 if $state >= scalar(@colors);
		}
		# make sure it is reset to default so colors don't "leak"
		# into the outline() routine
		$line = $newline . "[0m";

		# increment rowcount/swap offset
		$rownum++;
		if ($rownum == $checksize) {
			$rownum = 0;
			$offset++; $offset = 0 if $offset >= scalar(@colors);
		}
	}
	return join("\n", @text);
}

sub rainbow {
	# make colorful text
	my ($text, $style) = @_;

	# calculate stateful color offset
	my $state_offset = 0;
	if (Irssi::settings_get_bool("rainbow_keepstate")) {
		$state_offset = Irssi::settings_get_int("rainbow_offset");
		if ($state_offset < 0 or $state_offset > 20) {
			$state_offset = 0;
		} else {
			$state_offset++;
		}

		Irssi::settings_set_int("rainbow_offset", $state_offset);
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
		my $rand = int(rand(0) * 6) + 1;
		if ($rand == 1) {
			# blue
			@colormap = (2,12,2,12,2,12,2,12,2,12,2,12,2,12,2,12,2,12,2,12,2,12,2,12);
		} elsif ($rand == 2) {
			# green
			@colormap = (3,9,3,9,3,9,3,9,3,9,3,9,3,9,3,9,3,9,3,9,3,9,3,9);
		} elsif ($rand == 3) {
			# purple
			@colormap = (6,13,6,13,6,13,6,13,6,13,6,13,6,13,6,13,6,13,6,13,6,13,6,13);
		} elsif ($rand == 4) {
			# gray
			@colormap = (14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15,14,15);
		} elsif ($rand == 5) {
			# yellow
			@colormap = (7,8,7,8,7,8,7,8,7,8,7,8,7,8,7,8,7,8,7,8,7,8,7,8);
		} elsif ($rand == 6) {
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
	} else {
		# invalid style setting
		Irssi::print("invalid style setting: $style");
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
			$color = $color ?  $colormap[$color %($#colormap-1)] : $colormap[0];
			$newtext .= "\003$color" unless ($chr =~ /\s/);
			my $ord = ord($chr);
			if (($ord >= 48 and $ord <= 57) or $ord == 44) {
				$newtext .= "\26\26";
			}
			$newtext .= $chr;
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
		push(@newtext, "[5m$line[0m");
	}
	return join("\n", @newtext);
}

sub clean_length {
	my $text = shift;
	$text =~ s/\x03\d+(,\d+)?(\26\26)?//g;
	$text =~ s/\[0m//g;
	return length($text);
}

sub matrix {
	# 0-day greetz to EnCapSulaTE1!11!one
	my $text = shift;
	my $size = Irssi::settings_get_int("matrix_size");
	my $spacing = Irssi::settings_get_int("matrix_spacing");

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
	foreach my $path (split(/:/, $ENV{PATH})) {
		my $test = "$path/$cmd";
		if (-x $test) {
			return $test;
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
		Irssi::print("could not open $file: $!");
		return;
	}

	my $max = Irssi::settings_get_int("colcat_max");
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

	open3(*READ, *WRITE, *ERR, $text);
	close WRITE;

	$text = join('', <READ>);
	close READ;
	
	# check for errors
	show_error(join('', <ERR>));
	close ERR;

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

COMMANDS:
/gay                 just like /say, but gay
/gay help            this help screen
/gay version         show version information
/gay usage           just show usage line
/gay update          check for new release & update
/gayexec             like /exec, but gayer
/gaycat              pipe a file
/gv                  tell the world you're gay

SETTINGS:

cowfile <cowsay file>
figfont <figlet file>
linewrap <# to wrap at>
cowsay_cmd <path to cowsay program>
figlet_cmd <path to figlet program>
jive_cmd <path to jive program>
colcat_max # 
gay_default_style #
rainbow_keepstate <ON|OFF>
check_size #
check_colors #,#,...
check_text #
matrix_size, #
matrix_spacing #
spook_words #
hug_size #
EOH
	Irssi::print(draw_box($SPLASH, $help, undef, 1), MSGLEVEL_CLIENTCRAP);
}

sub draw_box {
	# taken from a busted script distributed with irssi
	# just a simple ascii line-art around help text
	my ($title, $text, $footer, $color) = @_;
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

sub show_error {
	# take text gathered from STDERR and pass it here
	# to display to the client
	my $text = shift;
	foreach my $line (split(/\n/, $text)) {
		Irssi::print($line);
	}
}

sub open3 {
	my ($read, $write, $err, $command) = @_;

	pipe($read, RTMP);
	pipe($err, ETMP);
	pipe(WTMP, $write);

	select($read); $| = 1;
	select($err); $| = 1;
	select($write); $| = 1;
	select(STDOUT);

	return 0 unless defined $command;

	# fork
	my $pid = fork();
	if ($pid) {
		# parent
		$child_pid = $pid;
		$SIG{CHLD} = \&sigchild_handler;
		close RTMP; close WTMP; close ETMP;
		return $pid;
	} else {
		# child
		close $write; close $read; close $err;
		open(STDIN,  "<&WTMP"); close WTMP;
		open(STDOUT, ">&RTMP"); close RTMP;
		open(STDERR, ">&ETMP"); close ETMP;
		exec($command);
		exit 0;
	}
}

sub update {
	# automatically check for updates
	my $baseURL = $IRSSI{download} . "/" . $IRSSI{name};
	
	# do we have useragent?
	eval "use LWP::UserAgent";
	if ($@) {
		Irssi::print("LWP::UserAgent failed to load: $!");
		return;
	}

	# first see what the latest version is
	my $ua = LWP::UserAgent->new();
	$ua->agent("$IRSSI{name}-$IRSSI{version} updater");
	my $req = HTTP::Request->new(GET => "$baseURL/CURRENT");
	my $res = $ua->request($req);
	if (!$res->is_success()) {
		Irssi::print("Problem contacting the mothership: " . $res->status_line());
		return;
	}

	my $latest_version = $res->content(); chomp $latest_version;
	Irssi::print("Your version is: $VERSION");
	Irssi::print("Current version is: $latest_version");

	if ($VERSION >= $latest_version) {
		Irssi::print("You are up to date");
		return;
	}

	# uh oh, old stuff!  time to update
	Irssi::print("You are out of date, fetching latest");
	$req = HTTP::Request->new(GET => "$baseURL/$IRSSI{name}-$latest_version.pl");

	my $script_dir = Irssi::get_irssi_dir() . "/scripts";
	my $saveTo = "$script_dir/downloaded-$IRSSI{name}.pl";
	$res = $ua->request($req, $saveTo);
	if (!$res->is_success()) {
		Irssi::print("Problem contacting the mothership: " . $res->status_line());
		return;
	}

	# copy to location
	rename($saveTo, "$script_dir/$IRSSI{name}.pl");

	Irssi::print("Updated successfully! '/run $IRSSI{name}' to load");
}


sub spookify {
	# add emacs spook text.  if there is previously existing text, it appends
	my $text = shift;
	my $count = Irssi::settings_get_int('spook_words') || return $text;
	my @spook_words;
	for (my $i = 0; $i < $count; $i++) {
		my $word = $spook_lines[int(rand(0) * scalar(@spook_lines))];
		push(@spook_words, $word);
	}
	my $text = join(" ", @spook_words) . " $text";
	return $text;
}

sub wrap {
	# fix that shit
	my $text = shift;
	my $wrap = Irssi::settings_get_int("linewrap") || return $text;
	$Text::Wrap::columns = $wrap;
	my @output;
	foreach my $line (split(/\n/, $text)) {
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
	my $size = Irssi::settings_get_int("hug_size");

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
		Irssi::print("Unmatched escape");
		return;
	}

	while ($text ne '') {
		$field = '';
		for (;;) {
			if ($text =~ s/^"(([^"\\]|\\.)*)"//) {
				($snippet = $1) =~ s#\\(.)#$1#g;
			} elsif ($text =~ /^"/) {
				Irssi::print("Unmatched double quote");
				return;
			} elsif ($text =~ s/^'(([^'\\]|\\.)*)'//) {
				($snippet = $1) =~ s#\\(.)#$1#g;
			} elsif ($text =~ /^'/) {
				Irssi::print("Unmatched single quote");
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

# command bindings
Irssi::command_bind("gay", \&gay);
Irssi::command_bind("colcow", \&colcow);
Irssi::command_bind("gayexec", \&gayexec);
Irssi::command_bind("gaycat", \&gaycat);
Irssi::command_bind("gv", \&gv);


############
# settings #
############

# cowsay
Irssi::settings_add_str($IRSSI{name}, 'cowfile', 'default');
Irssi::settings_add_str($IRSSI{name}, 'cowsay_cmd', 'cowsay');

# figlet
Irssi::settings_add_str($IRSSI{name}, 'figfont', 'standard');
Irssi::settings_add_int($IRSSI{name}, 'linewrap', 50);
Irssi::settings_add_str($IRSSI{name}, 'figlet_cmd', 'figlet');

# rainbow
Irssi::settings_add_int($IRSSI{name}, 'rainbow_offset', 0);
Irssi::settings_add_bool($IRSSI{name}, 'rainbow_keepstate', 1);
Irssi::settings_add_int($IRSSI{name}, 'gay_default_style', 1);

# checkers
Irssi::settings_add_int($IRSSI{name}, 'check_size', 3);
Irssi::settings_add_int($IRSSI{name}, 'check_text', 0);
Irssi::settings_add_str($IRSSI{name}, 'check_colors', "4,2");

# the matrix
Irssi::settings_add_int($IRSSI{name}, "matrix_size", 6);
Irssi::settings_add_int($IRSSI{name}, "matrix_spacing", 2);

# misc
Irssi::settings_add_int($IRSSI{name}, 'colcat_max', 2048);
Irssi::settings_add_str($IRSSI{name}, 'jive_cmd', 'jive');
Irssi::settings_add_int($IRSSI{name}, 'spook_words', 6);
Irssi::settings_add_int($IRSSI{name}, 'hug_size', 5);

###########
# startup #
###########

Irssi::print("$SPLASH.  '/gay help' for usage");

