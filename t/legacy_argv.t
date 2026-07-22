#!perl

use strict;
use warnings;
use Test::More;
use CAPE::Utils::Cmd;

# native invocations (no -a) must pass through untouched
is_deeply(
	[ CAPE::Utils::Cmd->legacy_rewrite(qw(submit -i /etc/x.ini foo.exe)) ],
	[qw(submit -i /etc/x.ini foo.exe)],
	'native command line is unchanged'
);

is_deeply( [ CAPE::Utils::Cmd->legacy_rewrite() ], [], 'empty argv is unchanged' );

# legacy "-a <action>" becomes the leading sub command
is_deeply( [ CAPE::Utils::Cmd->legacy_rewrite(qw(-a submit foo.exe)) ],
	[qw(submit foo.exe)], '-a <action> is promoted to the sub command' );

# -a=action form
is_deeply( [ CAPE::Utils::Cmd->legacy_rewrite(qw(-a=submit foo.exe)) ],
	[qw(submit foo.exe)], '-a=<action> is promoted to the sub command' );

# --action long form, both spellings
is_deeply( [ CAPE::Utils::Cmd->legacy_rewrite(qw(--action running -C)) ],
	[qw(running -C)], '--action <action> is promoted to the sub command' );
is_deeply( [ CAPE::Utils::Cmd->legacy_rewrite(qw(--action=running -C)) ],
	[qw(running -C)], '--action=<action> is promoted to the sub command' );

# -c/--config is remapped to -i in legacy mode
is_deeply(
	[ CAPE::Utils::Cmd->legacy_rewrite(qw(-a submit -c /etc/x.ini foo.exe)) ],
	[qw(submit -i /etc/x.ini foo.exe)],
	'-c <ini> is remapped to -i'
);
is_deeply(
	[ CAPE::Utils::Cmd->legacy_rewrite(qw(-a submit --config=/etc/x.ini foo.exe)) ],
	[qw(submit -i /etc/x.ini foo.exe)],
	'--config=<ini> is remapped to -i'
);

# a full legacy line with mixed flags
is_deeply(
	[ CAPE::Utils::Cmd->legacy_rewrite(qw(-a submit -c /etc/x.ini --json --timeout 60 foo.exe bar.exe)) ],
	[qw(submit -i /etc/x.ini --json --timeout 60 foo.exe bar.exe)],
	'full legacy submit line rewrites correctly'
);

# -c without -a is left alone (native mode is not engaged)
is_deeply( [ CAPE::Utils::Cmd->legacy_rewrite(qw(running -c foo)) ],
	[qw(running -c foo)], '-c is not remapped without the legacy -a flag' );

done_testing;
