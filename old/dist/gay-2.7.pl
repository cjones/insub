# unleash the gay!!!  shoutz to #insub
# author: cj_ <rover@gruntle.org>
# type /gay help for usage after loading

use Irssi;
use Irssi::Irc;
use strict;
use vars qw($VERSION %IRSSI $SPLASH);

$VERSION = "2.7";
%IRSSI = (
	author		=> 'cj_',
	contact		=> 'rover@gruntle.org',
	download	=> 'http://gruntle.org/projects/gay',
	name		=> 'gay',
	description	=> 'a lot of annoying ascii color/art text filters',
	license		=> 'Public Domain',
	changed		=> 'Wed Jul 16 18:41:52 PDT 2003',
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

# these are aliases that use a predefined set of filters
sub gv        { process("v",   @_) }	# display version info
sub colcow    { process("cr",  @_) }	# cowsay -> rainbow
sub figcow    { process("cf",  @_) }	# figlet -> cowsay
sub figcolcow { process("crf", @_) }	# figlet -> cowsay -> rainbow
sub colfig    { process("rf",  @_) }	# figlet -> rainbow
sub gayexec   { process("e",   @_) }    # execute

# main interface command.  without switches, it's
# just like /say
sub gay {
	my $text = shift;
	if ($text =~ /^help/i) {
		# show help
		show_help();
	} elsif ($text =~ /^vers/i) {
		# just show version
		Irssi::print($SPLASH);
	} elsif ($text =~ /^update/i) {
		# contact mothership and update
		update();
	} else {
		# raw command. w/o switches, will just
		# be a /say
		process(undef, $text, @_);
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

	return unless $dest;

	# set up defaults
	my @text;
	my $prefix;
	my $style = Irssi::settings_get_int("gay_default_style");
	my $cowfile = Irssi::settings_get_str("cowfile");
	my $figfont = Irssi::settings_get_str("figfont");
	my $sendto = $dest->{name};

	# parse args
	my @args = shell_args($text);
	while (my $arg = shift(@args)) {
		if ($arg =~ /^-msg/)     { $sendto = shift(@args); next }
		if ($arg =~ /^-pre/)     { $prefix = shift(@args); next }
		if ($arg =~ /^-blink/)   { $flags .= "b"; next }
		if ($arg =~ /^-jive/)    { $flags .= "j"; next }
		if ($arg =~ /^-cowfile/) { $cowfile = shift(@args); next }
		if ($arg =~ /^-cow/)     { $flags .= "c"; next }
		if ($arg =~ /^-fig/)     { $flags .= "f"; next }
		if ($arg =~ /^-font/)    { $figfont = shift(@args); next }
		if ($arg =~ /^-box/)     { $flags .= "o"; next }
		if ($arg =~ /^-(\d)$/)   { $flags .= "r"; $style = $1; next }

		# doesn't match arguments, must be text!
		push(@text, $arg);
	}
	$text = join(" ", @text);


	##############################
	# filter text based on flags #
	##############################
	
	# where to get text
	$text = "$IRSSI{name} $IRSSI{version} - $IRSSI{download}" if $flags =~ /v/;
	$text = execute($text)           if $flags =~ /e/;
	$text = slurp($text)             if $flags =~ /x/;

	# change the text contents itself
	$text = jive($text)              if $flags =~ /j/;

	# change the text appearance
	$text = figlet($text, $figfont)  if $flags =~ /f/;

	# change the text presentation
	$text = cowsay($text, $cowfile)  if $flags =~ /c/;
	$text = outline($text)           if $flags =~ /o/;

	# change the final products visual appearance
	$text = rainbow($text, $style)   if $flags =~ /r/;
	$text = blink($text)             if $flags =~ /b/;

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

sub outline {
	# draw a box around text.. thanks 2 twid
	my $text = shift;
	my @text = split(/\n/, $text);

	# what is the longest line
	my $length = 0;
	foreach my $line (@text) {
		$length = length($line) if length($line) > $length;
	}

	# add box around each line
	foreach my $line (@text) {
		$line = "| $line" . (" " x ($length - length($line) + 1)) . "|";
	}

	# top/bottom frame
	my $frame = "+" . ("-" x ($length + 2)) . "+";
	push(@text, $frame); unshift(@text, $frame);

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
/COMMAND [-123456] [-blink] [-msg <target>] [-pre <prefix text>]
         [-fig] [-font <figlet font>] [-cow] [-cowfile <cowfile>] 
         [-box] <text>

STYLES:
-1     rainbow
-2     red white and blue
-3     random colors
-4     random alternating colors
-5     alternating gray
-6     greyscale

COMMANDS:
/gay                 just like /say, but gay
/gayexec             like /exec, but gayer
/gay help            this help screen
/gay version         show version information
/gay update          check for new release & update
/gv                  tell the world you're gay

ALIASES:
/colcow <text>       color cowsay
/figcow <text>       cowsay w/ figlet fonts
/figcolcow <text>    color cow talking figlet
/colfig <text>       color figlet

SETTINGS:

/set cowfile <cowsay file>
/set figfont <figlet file>
/set figwrap <# to wrap at>
/set cowsay_cmd <path to cowsay program>
/set figlet_cmd <path to figlet program>
/set jive_cmd   <path to jive program>
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

sub update {
	# automatically check for updates
	my $baseURL = $IRSSI{download};
	
	# do we have useragent?
	eval "use LWP::UserAgent";
	if ($@) {
		Irssi::print("LWP::UserAgent failed to load: $!");
		return;
	}

	# first see what the latest version is
	my $ua = LWP::UserAgent->new();
	my $req = HTTP::Request->new(
		GET	=> "$baseURL/CURRENT",
	);
	my $res = $ua->request($req);
	if (!$res->is_success()) {
		Irssi::print("Problem contacting the mothership");
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
	$req = HTTP::Request->new(
		GET	=> "$baseURL/gay-$latest_version.pl",
	);
	$res = $ua->request($req);
	if (!$res->is_success()) {
		Irssi::print("Problem contacting the mothership");
		return;
	}

	my $src = $res->content();

	# check for integrity
	if ($src !~ /(\$VERSION = "$latest_version";)/s) {
		Irssi::print("Version mismatch, aborting");
		return;
	}

	# where should we save this?
	my $script_dir = "$ENV{HOME}/.irssi/scripts";
	if (! -d $script_dir) {
		Irssi::print("Could not determine script dir");
		return;
	}

	# save the shit already
	unless (open(OUT, ">$script_dir/downloaded-gay.pl")) {
		Irssi::print("Couldn't write to $script_dir/gay.pl: $!");
		return;
	}

	print OUT $src;
	close OUT;

	# copy to location
	rename("$script_dir/gay.pl", "$script_dir/gay-$VERSION.pl");
	rename("$script_dir/downloaded-gay.pl", "$script_dir/gay.pl");

	Irssi::print("Updated successfully! '/run gay' to load");
}

sub shell_args {
	# take a command-line and parse
	# it properly, return array ref
	# of args
	my $text = shift;
	my $arg_hash = {
		count	=> 1,
	};
	my @post_cmd;
	while ($text =~ /((["'])([^\2]*?)\2)/g) {
		my $arg = $3;
		my $string = $1;
		$string =~ s!/!\/!g;
		my $count = $arg_hash->{count};
		$arg_hash->{$count} = $arg;
		push(@post_cmd, "\$text =~ s/$string/*ARG$count*/");
		$count++;
		$arg_hash->{count} = $count;
	}

	foreach my $cmd (@post_cmd) {
		eval $cmd;
	}

	my @args;
	foreach my $arg (split(/\s+/, $text)) {
		if ($arg =~ /^\*ARG(\d+)\*$/) {
			my $count = $1;
			if ($arg_hash->{$count}) {
				$arg = $arg_hash->{$count};

			}
		}
		push(@args, $arg);
	}

	return @args;
}

# command bindings
Irssi::command_bind("colcow", \&colcow);
Irssi::command_bind("figcow", \&figcow);
Irssi::command_bind("figcolcow", \&figcolcow);
Irssi::command_bind("colfig", \&colfig);
Irssi::command_bind("gay", \&gay);
Irssi::command_bind("gv", \&gv);
Irssi::command_bind("gayexec", \&gayexec);


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
Irssi::settings_add_str($IRSSI{name}, 'jive_cmd', 'jive');

# display splash text
Irssi::print("$SPLASH.  '/gay help' for usage");


