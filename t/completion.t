#!perl

use strict;
use warnings;
use Test::More;
use File::Temp                            qw( tempdir );
use CAPE::Utils::Cmd                      ();
use CAPE::Utils::Cmd::Command::completion ();

my $completion = 'CAPE::Utils::Cmd::Command::completion';

#
# parse_option_spec
#
is_deeply(
	$completion->parse_option_spec( 'exec', [ 'dir|d=s', 'dir to run from' ] ),
	{ names => [ '--dir', '-d' ], description => 'dir to run from', takes_value => 1, value_hint => 'dir' },
	'long and short names, with a subcommand specific value hint'
);

is_deeply(
	$completion->parse_option_spec( 'running', [ 'ini|i=s', 'config' ] ),
	{ names => [ '--ini', '-i' ], description => 'config', takes_value => 1, value_hint => 'file' },
	'the ini value hint applies to every subcommand'
);

is_deeply(
	$completion->parse_option_spec( 'resub', [ 'r=i', 'task ID' ] ),
	{ names => ['-r'], description => 'task ID', takes_value => 1, value_hint => 'none' },
	'a value with no hint completes nothing'
);

is_deeply(
	$completion->parse_option_spec( 'tasks', [ 'direction=s', 'direction' ] )->{value_hint},
	[ 'asc', 'desc' ],
	'a value hint can be a fixed list'
);

is_deeply(
	$completion->parse_option_spec( 'submit', [ 'mime_package|mime-package!', 'mime' ] ),
	{
		names       => [ '--mime_package', '--mime-package', '--no-mime_package', '--no-mime-package' ],
		description => 'mime',
		takes_value => 0,
		value_hint  => undef,
	},
	'a negatable option gets --no- forms'
);

is_deeply(
	$completion->parse_option_spec( 'running', ['count|C'] ),
	{ names => [ '--count', '-C' ], description => '', takes_value => 0, value_hint => undef },
	'a flag without a description'
);

is( $completion->parse_option_spec( 'foo', [ 'level:i', 'optional value' ] )->{takes_value},
	0, 'an optional value does not count as taking one' );

#
# subcommand_specs
#
my $app         = CAPE::Utils::Cmd->new;
my $subcommands = $completion->subcommand_specs($app);
my %by_name     = map { $_->{name} => $_ } @{$subcommands};

my @expected_names = sort( grep { !/^-/ } $app->command_names );
is_deeply( [ map { $_->{name} } @{$subcommands} ], \@expected_names, 'every subcommand is present, sorted' );
ok( !grep( { /^-/ } keys(%by_name) ), 'dashed aliases such as --help are skipped' );

is( $by_name{exec}{positional},     'command',          'exec positionals are a command' );
is( $by_name{help}{positional},     'subcommand',       'help positionals are subcommands' );
is( $by_name{version}{description}, 'show the version', 'fallback description used for version' );
is( $by_name{running}{positional},  undef,              'running has no positionals' );
is_deeply( $by_name{completion}{positional}, [ 'bash', 'zsh' ], 'completion positional is the shell' );

my ($exec_dir) = grep { $_->{names}[0] eq '--dir' } @{ $by_name{exec}{options} };
ok( defined($exec_dir), 'exec has --dir' );
is( $exec_dir->{value_hint}, 'dir', 'exec --dir completes dirs' );

#
# bash script
#
my $bash_script = $completion->bash_script($subcommands);
like( $bash_script, qr/^complete -F _cape_utils cape_utils$/m, 'bash script registers the completion' );
foreach my $subcommand ( @{$subcommands} ) {
	foreach my $option ( @{ $subcommand->{options} } ) {
		foreach my $option_name ( @{ $option->{names} } ) {
			like(
				$bash_script,
				qr/^\t\['\Q$subcommand->{name}\E'\]='[^']*(?<=[' ])\Q$option_name\E(?=[' ])/m,
				'bash: ' . $subcommand->{name} . ' ' . $option_name
			);
		}
	}
} ## end foreach my $subcommand ( @{$subcommands} )

my $temp_dir = tempdir( CLEANUP => 1 );

SKIP: {
	my $bash = `command -v bash 2>/dev/null`;
	chomp($bash);
	skip( 'bash not found', 1 ) if $bash eq '';

	my $script_file = $temp_dir . '/cape_utils.bash';
	open( my $script_fh, '>', $script_file ) || die( 'Unable to write "' . $script_file . '"' );
	print $script_fh $bash_script;
	close($script_fh);

	is( system( $bash, '-n', $script_file ), 0, 'bash script passes bash -n' );

	# a dir to complete and a command only found in the temp dir, so what is
	# offered does not depend on what the machine has installed
	mkdir( $temp_dir . '/subdir' );
	mkdir( $temp_dir . '/bin' );
	my $test_command = $temp_dir . '/bin/cape_utils_test_command';
	open( my $command_fh, '>', $test_command ) || die( 'Unable to write "' . $test_command . '"' );
	print $command_fh "#!/bin/sh\n";
	close($command_fh);
	chmod( 0755, $test_command );

	# runs _cape_utils from the temp dir for a command line and returns what it
	# offered, sorted, the last word being the one being completed
	my $bash_code = 'source "$1"; shift; cd "$1"; shift; COMP_WORDS=( "$@" ); '
		. 'COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 )); _cape_utils; printf "%s\n" "${COMPREPLY[@]}"';
	my $complete = sub {
		my @words = @_;
		local $ENV{PATH} = $temp_dir . '/bin:' . $ENV{PATH};
		open( my $output_fh, '-|', $bash, '-c', $bash_code, 'bash', $script_file, $temp_dir, @words )
			|| die('Unable to run bash');
		my @offered = grep { $_ ne '' } map { chomp; $_ } <$output_fh>;
		close($output_fh);
		return [ sort(@offered) ];
	};

	is_deeply( $complete->( 'cape_utils', 'e' ),                        [ 'eve', 'exec' ], 'bash: subcommand names' );
	is_deeply( $complete->( 'cape_utils', 'exec', '--d' ),              ['--dir'],         'bash: option names' );
	is_deeply( $complete->( 'cape_utils', 'exec', '-d', 'sub' ),        ['subdir'],        'bash: dir value' );
	is_deeply( $complete->( 'cape_utils', 'tasks', '--direction', '' ), [ 'asc', 'desc' ], 'bash: fixed values' );
	is_deeply( $complete->( 'cape_utils', 'resub', '-r', '' ), [], 'bash: a value with no hint completes nothing' );
	is_deeply( $complete->( 'cape_utils', 'help', 'ru' ),      ['running'],       'bash: help completes subcommands' );
	is_deeply( $complete->( 'cape_utils', 'completion', '' ),  [ 'bash', 'zsh' ], 'bash: completion shells' );
	is_deeply(
		$complete->( 'cape_utils', 'exec', '--', 'cape_utils_test_comm' ),
		['cape_utils_test_command'],
		'bash: command name after -- for exec'
	);
	is_deeply( $complete->( 'cape_utils', 'exec', '--', 'cape_utils_test_command', 'sub' ),
		['subdir'], 'bash: files after the command for exec' );
} ## end SKIP:

#
# zsh script
#
my $zsh_script = $completion->zsh_script($subcommands);
like( $zsh_script, qr/^#compdef cape_utils$/m, 'zsh script has the compdef line' );
like(
	$zsh_script,
	qr/^\t+'\(--dir -d\)--dir=\[[^\]]+\]:dir:_files -\/' \\$/m,
	'zsh: exec --dir completes dirs and excludes -d'
);
like( $zsh_script, qr/HH\\:MM\\:ss/,                     'zsh: colons in descriptions are escaped' );
like( $zsh_script, qr/^\t+'version:show the version'$/m, 'zsh: subcommand descriptions' );

SKIP: {
	my $zsh = `command -v zsh 2>/dev/null`;
	chomp($zsh);
	skip( 'zsh not found', 1 ) if $zsh eq '';

	my $script_file = $temp_dir . '/_cape_utils';
	open( my $script_fh, '>', $script_file ) || die( 'Unable to write "' . $script_file . '"' );
	print $script_fh $zsh_script;
	close($script_fh);

	is( system( $zsh, '-n', $script_file ), 0, 'zsh script passes zsh -n' );
} ## end SKIP:

done_testing;
