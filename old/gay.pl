# unleash the gay!!!  shoutz to #insub
# author: cj_ <rover@gruntle.org>
# type /gay help for usage after loading

use Irssi;
use Irssi::Irc;
use strict;
use vars qw($VERSION %IRSSI $SPLASH);

$VERSION = "1.4";
%IRSSI = (
	author		=> 'cj_',
	contact		=> 'rover@gruntle.org',
	name		=> 'gay',
	description	=> 'a lot of annoying ascii color/art text filters',
	license		=> 'Public Domain',
	changed		=> 'Tue Jul 15 18:23:02 PDT 2003',
	version		=> $VERSION,
);

# this is for displaying in various places to bug the user
$SPLASH = "$IRSSI{name} $IRSSI{version} by $IRSSI{author} <$IRSSI{contact}>";

# handler to reap dead children                                                                                              
# need this to avoid zombie/defunt processes
# waiting around to have their exit status read
my $child_pid;                                                                                                               
sub sigchild_handler {                                                                                                       
	waitpid($child_pid, 0);                                                                                              
}


###############################
# these are the main commands #
###############################

# these work by calling a single routine with flags indicating
# which filters the text should be passed through.  the order
# they are parsed is not changeable.  see the process() function
# for an explanation of flags
sub cow       { process("c",   @_) }	# cowsay
sub colcow    { process("cr",  @_) }	# cowsay -> rainbow
sub figcow    { process("cf",  @_) }	# figlet -> cowsay
sub figcolcow { process("crf", @_) }	# figlet -> cowsay -> rainbow
sub colcat    { process("xr",  @_) }    # file -> rainbow
sub figsay    { process("f",   @_) }	# figlet
sub colfig    { process("rf",  @_) }	# figlet -> rainbow
sub gaysay    { process("r",   @_) }	# rainbow
sub colexec   { process("re",  @_) }	# exec -> rainbow
sub blinksay  { process("b",   @_) }    # blink

# interface command.  currently serves "help" and "version"
# later add "raw" command to let user supply filter flags
sub gay {
	my $args = shift;
	if ($args =~ /help/i) {
		show_help();
	} elsif ($args =~ /vers/i) {
		Irssi::print($SPLASH);
	}
}

###############################
# this handles the processing #
###############################

sub process {
	my ($flags, $text, $server, $dest) = @_;

	if (!$server || !$server->{connected}) {
		Irssi::print("Not connected to server");
		return;
	}

	# set up defaults
	my @text;
	my $prefix;
	my $style = Irssi::settings_get_int("gay_default_style");
	my $cowfile = Irssi::settings_get_str("cowfile");
	my $figfont = Irssi::settings_get_str("figfont");
	my $sendto = $dest->{name};

	# parse args
	my @args = split(/\s+/, $text);
	while (my $arg = shift(@args)) {
		if ($arg =~ /^-m/) { $sendto = shift(@args); next }
		if ($arg =~ /^-p/) { $prefix = shift(@args); next }
		if ($arg =~ /^-b/) { $flags .= "b"; next }

		# conditional switches (for example, don't parse -c unless there's a cowsay
		if ($flags =~ /c/ and $arg =~ /^-c/)     { $cowfile = shift(@args); next }
		if ($flags =~ /f/ and $arg =~ /^-f/)     { $figfont = shift(@args); next }
		if ($flags =~ /r/ and $arg =~ /^-(\d)$/) { $style = $1; next }

		# doesn't match arguments, must be text!
		push(@text, $arg);
	}
	$text = join(" ", @text);

	return unless $dest;

	# do the evil stuff based on flags passed in.. these
	# routines are below
	$text = execute($text)           if $flags =~ /e/;
	$text = slurp($text)             if $flags =~ /x/;
	$text = figlet($text, $figfont)  if $flags =~ /f/;
	$text = cowsay($text, $cowfile)  if $flags =~ /c/;
	$text = rainbow($text, $style)   if $flags =~ /r/;
	$text = blink($text)             if $flags =~ /b/;

	# output and then we're done
	foreach my $line (split(/\n/, $text)) {
		$line = "$prefix $line" if ($prefix);
		$server->command("msg $sendto $line");
	}
}

######################################################
# these filters pass text through various gayalizers #
######################################################

sub cowsay {
	# pass text through cowsay
	my $text = shift;
	my $cowsay_font = shift || 'default';

	# see if we can find the program
	my $cowsay_cmd = Irssi::settings_get_str('cowsay_cmd');
	$cowsay_cmd = -x $cowsay_cmd ? $cowsay_cmd : whereis("cowsay");
	unless (-x $cowsay_cmd) {
		Irssi::print("$cowsay_cmd not found or not executable!");
		return;
	}

	open3(*READ, *WRITE, *ERR, "$cowsay_cmd -n -f $cowsay_font");
	print WRITE $text;
	close WRITE;

	$text = join('', <READ>);
	close READ;

	# check for errors
	show_error(join('', <ERR>));
	close ERR;

	return $text;
}

sub figlet {
	# pass text through figlet
	my $text = shift;
	my $figlet_font = shift || 'standard';
	my $figlet_wrap = Irssi::settings_get_int('figwrap');

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

	$text =~ s/\n\s+\n$//s;   # figlet leaves a trailing blank line.. sometimes

	return $text;
}

sub rainbow {
	# take text and make it colorful
	#
	# 0 = white
	# 1 = black
	# 2 = blue
	# 3 = green
	# 4 = orange
	# 5 = red (yellow in bx/epic/ircii :( )
	# 6 = magenta
	# 7 = yellow  (red in bx/epic/ircii :( )
	# 8 = bright yellow
	# 9 = bright green
	# 10 = cyan
	# 11 = gray
	# 12 = bright blue
	# 13 = bright purple
	# 14 = dark gray
	# 15 = light gray
	
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

	# colorize.. thanks 2 sisko
	my $newtext;
	my $row = 0;
	foreach my $line (split(/\n/, $text)) {
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
/COMMAND [-12345] [-b] [-m <target>] [-p <prefix text>]
         [-f <figlet font>] [-c <cowfile>] <text>

STYLES:
-1     rainbow  (default, changeable)
-2     red white and blue
-3     random colors
-4     random alternating colors
-5     alternating gray
-6     greyscale
-b     blinking (can be combined)

COMMANDS:

/cow <text>          regular cowsay
/colcow <text>       color cowsay
/figcow <text>       cowsay w/ figlet fonts
/figcolcow <text>    d) all of the above!!oneone
/colcat <text>       output file in color
/colexec <command>   execute command in color
/gaysay <text>       say in color
/figlet <text>       output in figlet
/colfig <text>       color figlet
/blink <text>        just say something, blinking
/gay help            this help screen
/gay version         show version information

SETTINGS:

/set cowfile <cowsay file>
/set figfont <figlet file>
/set figwrap <# to wrap at>
/set cowsay_cmd <path to cowsay program>
/set figlet_cmd <path to figlet program>
/set gay_default_style #
/set rainbow_keepstate <ON|OFF>
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

# command bindings
Irssi::command_bind("cow", \&cow);
Irssi::command_bind("colcow", \&colcow);
Irssi::command_bind("figcow", \&figcow);
Irssi::command_bind("figcolcow", \&figcolcow);
Irssi::command_bind("colcat", \&colcat);
Irssi::command_bind("figlet", \&figsay);
Irssi::command_bind("colfig", \&colfig);
Irssi::command_bind("gaysay", \&gaysay);
Irssi::command_bind("colexec", \&colexec);
Irssi::command_bind("blink", \&blinksay);
Irssi::command_bind("gay", \&gay);

# settings
Irssi::settings_add_str($IRSSI{name}, 'cowfile', 'default');
Irssi::settings_add_str($IRSSI{name}, 'figfont', 'standard');
Irssi::settings_add_int($IRSSI{name}, 'figwrap', 50);
Irssi::settings_add_str($IRSSI{name}, 'cowsay_cmd', 'cowsay');
Irssi::settings_add_str($IRSSI{name}, 'figlet_cmd', 'figlet');
Irssi::settings_add_int($IRSSI{name}, 'colcat_max', 2048);
Irssi::settings_add_int($IRSSI{name}, 'rainbow_offset', 0);
Irssi::settings_add_bool($IRSSI{name}, 'rainbow_keepstate', 1);
Irssi::settings_add_int($IRSSI{name}, 'gay_default_style', 1);

# display splash text
Irssi::print("$SPLASH.  '/gay help' for usage");


