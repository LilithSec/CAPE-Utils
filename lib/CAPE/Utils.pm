package CAPE::Utils;

use 5.006;
use strict;
use warnings;
use JSON;
use Config::Tiny;
use DBI;
use File::Slurp;
use Config::Tiny;
use Hash::Merge;
use IPC::Cmd qw[ run ];
use Text::ANSITable;
use File::Spec;

=head1 NAME

CAPE::Utils - A helpful library for with CAPE.

=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use CAPE::Utils;

    my $foo = CAPE::Utils->new();
    ...

=head1 METHODS

=head2 new

Initiates the object. One argument is taken and that is the
path to the INI config file. The default is '/usr/local/etc/cape_utils.ini'
and if not found, the defaults will be used.

    my $cape_util=CAPE::Utils->new('/path/to/some/config.ini');

=cut

sub new {
	my $ini = $_[1];

	if ( !defined($ini) ) {
		$ini = '/usr/local/etc/cape_utils.ini';
	}

	my $base_config = {
		'_' => {
			dsn                 => 'dbi:Pg:dbname=cape',
			user                => 'cape',
			pass                => '',
			base                => '/opt/CAPEv2/',
			poetry              => 1,
			fail_all            => 0,
			pending_columns     => 'id,target,package,timeout,ET,route,options,clock,added_on',
			running_columns     => 'id,target,package,timeout,ET,route,options,clock,added_on,started_on,machine',
			running_target_clip => 1,
			running_time_clip   => 1,
			pending_target_clip => 1,
			pending_time_clip   => 1,
			table_color         => 'Text::ANSITable::Standard::NoGradation',
			table_border        => 'ASCII::None',
			set_clock_to_now    => 1,
			timeout             => 200,
			enforce_timeout     => 0,
		},
	};

	my $config = Config::Tiny->read( $ini, 'utf8' );
	if ( !defined($config) ) {
		$config = $base_config;
	}
	else {
		$config = %{ merge( $base_config, $config ) };
	}

	# init the object
	my $self = { config => $config, };
	bless $self;

	return $self;
}

=head2 connect

Return a DBH from DBI->connect for the CAPE SQL server.

This will die with the output from $DBI::errstr if it fails.

    my $dbh = $cape->connect;

=cut

sub connect {
	my $self = $_[0];

	my $dbh = DBI->connect( $self->{config}->{_}->{dsn}, $self->{config}->{_}->{user}, $self->{config}->{_}->{pass} )
		|| die($DBI::errstr);

	return $dbh;
}

=head2 fail

Set a pending tasks to failed.

=cut

sub fail {
	my ( $self, %opts ) = @_;

	if ( defined( $opts{where} ) && $opts{where} =~ /\;/ ) {
		die '$opts{where},"' . $opts{where} . '", contains a ";"';
	}

	if ( !defined( $opts{where} ) && !$self->{config}->{_}->{fail_all} ) {
		die "fail_all is disabled and nothing specified for where";
	}

	my $dbh = $self->connect;

	my $statement = "UPDATE tasks SET status = 'failed_processing' WHERE status = 'pending'";

	if ( defined( $opts{where} ) ) {
		$statement = $statement . ' AND ' . $opts{where};
	}

	$statement = $statement . ';';

	my $sth = $dbh->prepare($statement);

	$sth->execute;

	my $rows = $sth->rows;

	$sth->finish;
	$dbh->disconnect;

	return $rows;
}

=head2 get_pending_count

Get pending count of 

=cut

sub get_pending_count {
	my ( $self, %opts ) = @_;

	if ( defined( $opts{where} ) && $opts{where} =~ /\;/ ) {
		die '$opts{where},"' . $opts{where} . '", contains a ";"';
	}

	my $dbh = $self->connect;

	my $statement = "select * from tasks where status = 'pending'";
	if ( defined( $opts{where} ) ) {
		$statement = $statement . ' AND ' . $opts{where};
	}

	my $sth = $dbh->prepare($statement);
	$sth->execute;

	my $rows = $sth->rows;

	$sth->finish;
	$dbh->disconnect;

	return $rows;
}

=head2 get_pending

Returns a arrah ref of hash refs of rows from the tasks table where the
status is set to

    - where :: Additional SQL where statements to add.

=cut

sub get_pending {
	my ( $self, %opts ) = @_;

	if ( defined( $opts{where} ) && $opts{where} =~ /\;/ ) {
		die '$opts{where},"' . $opts{where} . '", contains a ";"';
	}

	my $dbh = $self->connect;

	my $statement = "select * from tasks where status = 'pending'";
	if ( defined( $opts{where} ) ) {
		$statement = $statement . ' AND ' . $opts{where};
	}

	my $sth = $dbh->prepare($statement);
	$sth->execute;

	my $row;
	my @rows;
	while ( $row = $sth->fetchrow_hashref ) {
		push( @rows, $row );
	}

	$sth->finish;
	$dbh->disconnect;

	return \@rows;
}

=head2 get_pending_table

Generates a ASCII table for pending.

The following config variables can are relevant to this and
may be overriden.

    table_border
    table_color
    pending_columns
    pending_target_clip
    pending_time_clip

The following optionsa are also supported.

    - where :: Additional SQL where statements to add.

    print $cape_util->get_pending_table( pending_columns=>'id,package');

=cut

sub get_pending_table {
	my ( $self, %opts ) = @_;

	my @overrides = ( 'table_border', 'table_color', 'pending_columns', 'pending_target_clip', 'pending_time_clip' );
	foreach my $override (@overrides) {
		if ( !defined( $opts{$override} ) ) {
			$opts{$override} = $self->{config}->{_}->{$override};
		}
	}

	my $rows = $self->get_pending( where => $opts{where} );

	my $tb = Text::ANSITable->new;
	$tb->border_style( $opts{table_border} );
	$tb->color_theme( $opts{table_color} );

	my @columns    = split( /,/, $opts{pending_columns} );
	my $header_int = 0;
	my $padding    = 0;
	foreach my $header (@columns) {
		if   ( ( $header_int % 2 ) != 0 ) { $padding = 1; }
		else                              { $padding = 0; }

		$tb->set_column_style( $header_int, pad => $padding );

		$header_int++;
	}

	$tb->columns( \@columns );

	my @td;
	foreach my $row ( @{$rows} ) {
		my @new_line;
		foreach my $column (@columns) {
			if ( $column eq 'ET' ) {
				$row->{ET} = $row->{enforce_timeout};
			}

			if ( defined( $row->{$column} ) ) {
				if ( $column eq 'ET' ) {
					$row->{ET} = $row->{enforce_timeout};
				}

				if ( ( $column eq 'clock' || $column eq 'added_on' ) && $opts{pending_time_clip} ) {
					$row->{$column} =~ s/\.[0-9]+$//;
				}
				elsif ( $column eq 'target' && $opts{pending_target_clip} ) {
					$row->{target} =~ s/^.*\///;
				}
				push( @new_line, $row->{$column} );
			}
			else {
				push( @new_line, '' );
			}
		}

		push( @td, \@new_line );
	}

	$tb->add_rows( \@td );

	return $tb->draw;
}

=head2 get_running

Returns a arrah ref of hash refs of rows from the tasks table where the
status is set to pending.

=cut

sub get_running {
	my ( $self, %opts ) = @_;

	if ( defined( $opts{where} ) && $opts{where} =~ /\;/ ) {
		die '$opts{where},"' . $opts{where} . '", contains a ";"';
	}

	my $dbh = $self->connect;

	my $statement = "select * from tasks where status = 'running'";
	if ( defined( $opts{where} ) ) {
		$statement = $statement . ' AND ' . $opts{where};
	}

	my $sth = $dbh->prepare($statement);
	$sth->execute;

	my $row;
	my @rows;
	while ( $row = $sth->fetchrow_hashref ) {
		push( @rows, $row );
	}

	$sth->finish;
	$dbh->disconnect;

	return \@rows;
}

=head2 get_running_count

=cut

sub get_running_count {
	my ( $self, %opts ) = @_;

	if ( defined( $opts{where} ) && $opts{where} =~ /\;/ ) {
		die '$opts{where},"' . $opts{where} . '", contains a ";"';
	}

	my $dbh = $self->connect;

	my $statement = "select * from tasks where status = 'pending'";
	if ( defined( $opts{where} ) ) {
		$statement = $statement . ' AND ' . $opts{where};
	}

	my $sth = $dbh->prepare($statement);
	$sth->execute;

	my $rows = $sth->rows;

	$sth->finish;
	$dbh->disconnect;

	return $rows;
}

=head2 get_running_table

Generates a ASCII table for pending.

The following config variables can are relevant to this and
may be overriden.

    table_border
    table_color
    running_columns
    running_target_clip
    running_time_clip

The following optionsa are also supported.

    - where :: Additional SQL where statements to add.

    print $cape_util->get_pending_table( pending_columns=>'id,package');

=cut

sub get_running_table {
	my ( $self, %opts ) = @_;

	my @overrides = ( 'table_border', 'table_color', 'running_columns', 'running_target_clip', 'running_time_clip' );
	foreach my $override (@overrides) {
		if ( !defined( $opts{$override} ) ) {
			$opts{$override} = $self->{config}->{_}->{$override};
		}
	}

	my $rows = $self->get_running( where => $opts{where} );

	my $tb = Text::ANSITable->new;
	$tb->border_style( $opts{table_border} );
	$tb->color_theme( $opts{table_color} );

	my @columns    = split( /,/, $opts{running_columns} );
	my $header_int = 0;
	my $padding    = 0;
	foreach my $header (@columns) {
		if   ( ( $header_int % 2 ) != 0 ) { $padding = 1; }
		else                              { $padding = 0; }

		$tb->set_column_style( $header_int, pad => $padding );

		$header_int++;
	}

	$tb->columns( \@columns );

	my @td;
	foreach my $row ( @{$rows} ) {
		my @new_line;
		foreach my $column (@columns) {
			if ( $column eq 'ET' ) {
				$row->{ET} = $row->{enforce_timeout};
			}

			if ( defined( $row->{$column} ) ) {
				if ( $column eq 'ET' ) {
					$row->{ET} = $row->{enforce_timeout};
				}

				if ( ( $column eq 'clock' || $column eq 'added_on' || $column eq 'started_on' )
					&& $opts{running_time_clip} )
				{
					$row->{$column} =~ s/\.[0-9]+$//;
				}
				elsif ( $column eq 'target' && $opts{running_target_clip} ) {
					$row->{target} =~ s/^.*\///;
				}
				push( @new_line, $row->{$column} );
			}
			else {
				push( @new_line, '' );
			}
		}

		push( @td, \@new_line );
	}

	$tb->add_rows( \@td );

	return $tb->draw;
}

=head2 search

Set a pending tasks to failed.

=cut

sub search {
	my ( $self, %opts ) = @_;

	if ( defined( $opts{where} ) && $opts{where} =~ /\;/ ) {
		die '$opts{where},"' . $opts{where} . '", contains a ";"';
	}

	#
	# make sure all the set variables are not dangerous or potentially dangerous
	#

	if ( !defined( $opts{where} ) && !$self->{config}->{_}->{fail_all} ) {
		die "fail_all is disabled and nothing specified for where";
	}

	my @to_check = (
		'id',            'target',                 'route',            'machine',
		'timeout',       'priority',               'route',            'tags_tasks',
		'options',       'clock',                  'added_on',         'started_on',
		'completed_on',  'status',                 'dropped_files',    'running_processes',
		'api_calls',     'domains',                'signatures_total', 'signatures_alert',
		'files_written', 'registry_keys_modified', 'crash_issues',     'anti_issues',
		'timedout',      'sample_id',              'machine_id',       'parent_id',
		'tlp',           'category',               'package'
	);

	foreach my $var_to_check (@to_check) {
		if ( defined( $opts{$var_to_check} ) && $opts{$var_to_check} =~ /[\\\']/ ) {
			die( '"' . $opts{$var_to_check} . '" for "' . $var_to_check . '" matched /[\\\']/' );
		}
	}

	#
	# init the SQL statement
	#

	my $sql = "select * from tasks where id >= 0";

	if ( defined( $opts{where} ) ) {
		$sql = $sql . ' AND ' . $opts{where};
	}

	#
	# add simple items
	#

	my @simple = ( 'timeout', 'memory', 'enforce_timeout', 'timedout' );

	foreach my $item (@simple) {
		if ( defined( $opts{$item} ) ) {
			$sql = $sql . " and " . $item . " = '" . $opts{$item} . "'";
		}
	}

	#
	# add numeric items
	#

	my @numeric = (
		'id',                'timeout',       'priority',               'dropped_files',
		'running_processes', 'api_calls',     'domains',                'signatures_total',
		'signatures_alert',  'files_written', 'registry_keys_modified', 'crash_issues',
		'anti_issues',       'sample_id',     'machine_id'
	);

	foreach my $item (@numeric) {
		if ( defined( $opts{$item} ) ) {

			# remove and tabs or spaces
			$opts{$item} =~ s/[\ \t]//g;
			my @arg_split = split( /\,/, $opts{$item} );

			# process each item
			foreach my $arg (@arg_split) {

				# match the start of the item
				if ( $arg =~ /^[0-9]+$/ ) {
					$sql = $sql . " and " . $item . " = '" . $arg . "'";
				}
				elsif ( $arg =~ /^\<\=[0-9]+$/ ) {
					$arg =~ s/^\<\=//;
					$sql = $sql . " and " . $item . " <= '" . $arg . "'";
				}
				elsif ( $arg =~ /^\<[0-9]+$/ ) {
					$arg =~ s/^\<//;
					$sql = $sql . " and " . $item . " < '" . $arg . "'";
				}
				elsif ( $arg =~ /^\>\=[0-9]+$/ ) {
					$arg =~ s/^\>\=//;
					$sql = $sql . " and " . $item . " >= '" . $arg . "'";
				}
				elsif ( $arg =~ /^\>[0-9]+$/ ) {
					$arg =~ s/^\>\=//;
					$sql = $sql . " and " . $item . " > '" . $arg . "'";
				}
				elsif ( $arg =~ /^\![0-9]+$/ ) {
					$arg =~ s/^\!//;
					$sql = $sql . " and " . $item . " != '" . $arg . "'";
				}
				elsif ( $arg =~ /^$/ ) {

					# only exists for skipping when some one has passes something starting
					# with a ,, ending with a,, or with ,, in it.
				}
				else {
					# if we get here, it means we don't have a valid use case for what ever was passed and should error
					die( '"' . $arg . '" does not appear to be a valid item for a numeric search for the ' . $item );
				}
			}
		}
	}

	#
	# handle string items
	#

	my @strings
		= ( 'target', 'category', 'custom', 'machine', 'package', 'route', 'tags_tasks', 'options', 'platform', );

	foreach my $item (@strings) {
		if ( defined( $opts{$item} ) ) {
			if ( defined( $opts{ $item . '_like' } ) && $opts{ $item . '_like' } ) {
				$sql = $sql . " and host like '" . $opts{$item} . "'";
			}
			else {
				$sql = $sql . " and " . $item . " = '" . $opts{$item} . "'";
			}
		}
	}

	#
	# finalize it and search
	#

	$sql = $sql . ';';

	my $dbh = $self->connect;
	my $sth = $dbh->prepare($sql);

	$sth->execute;

	my $rows;

	return $rows;
}

=head2 submit

Submits files to CAPE.

    - clock :: Timestamp to use for setting the clock to of the VM for
      when executing the item. If left undefined, it will be
      autogenerated.
      - Format :: mm-dd-yyy HH:MM:ss

    - items :: A array ref of items to submit. If a directory is listed in
      here, it will be read, but subdirectories will not be recursed. They
      will be ignored.

    - name_regex :: Regex to use for matching items in a submitted dir.
      Only used if the a submitted item is a dir.
      - Default :: undef

    - mime_regex :: Array ref of desired mime types to match via
      regex. Only used if the a submitted item is a dir.
      - Default :: undef

    - timeout :: Value to use for timeout. Set to 0 to not enforce.
      - Default :: 200

    - machine :: The machine to use for this. If not defined, first
      available will be used.
      - Default :: undef

    - package :: Package to use, if not letting CAPE decide.
      - Default :: undef

    - options :: Option string to be passed via --options.
      - Default :: undef

    - random :: If it should randomize the order of submission.
      - Default :: 1

    - tags :: Tags to be passed to the script via --tags.
      - Default :: undef

    - platform :: What to pass to --platform.
      - Default :: undef

    - custom :: Any custom values to pass via --custom.
      - Default :: undef

    - enforce_timeout :: Force it to run the entire period.
      - Default :: 0

=cut

sub submit {
	my ( $self, %opts ) = @_;

	if ( !defined( $opts{items}[0] ) ) {
		die 'No items to submit passed';
	}

	if ( !defined( $opts{clock} ) && $self->{config}->{_}->{set_clock_to_now} ) {
		$opts{clock} = $self->timestamp;
	}

	if ( !defined( $opts{timeout} ) ) {
		$opts{timeout} = $self->{config}->{_}->{timeout};
	}

	if ( !defined( $opts{enforce_timeout} ) ) {
		$opts{enforce_timeout} = $self->{config}->{_}->{enforce_timeout};
	}

	my @to_submit;

	foreach my $item ( @{ $opts{items} } ) {
		if ( -f $item ) {
			push( @to_submit, File::Spec->rel2abs($item) );
		}
		elsif ( -d $item ) {
			opendir( my $dh, $item );
			while ( readdir($dh) ) {
				if ( -f $item . '/' . $_ ) {
					push( @to_submit, File::Spec->rel2abs( $item . '/' . $_ ) );
				}
			}
			closedir($dh);
		}
	}

	chdir( $self->{config}->{_}->{base} ) || die( 'Unable to CD to "' . $self->{config}->{_}->{base} . '"' );

	my @to_run = ();

	if ( $self->{config}->{_}->{poetry} ) {
		push( @to_run, 'poetry', 'run' );
	}

	push( @to_run, 'python3', $self->{config}->{_}->{base} . '/utils/submit.py' );

	if ( defined( $opts{clock} ) ) {
		push( @to_run, '--clock', $opts{clock} );
	}

	if ( defined( $opts{timeout} ) ) {
		push( @to_run, '--timeout', $opts{timeout} );
	}

	if ( $opts{enforce_timeout} ) {
		push( @to_run, '--enforce-timeout' );
	}

	if ( defined( $opts{package} ) ) {
		push( @to_run, '--package', $opts{package} );
	}

	if ( defined( $opts{machine} ) ) {
		push( @to_run, '--machine', $opts{machine} );
	}

	if ( defined( $opts{options} ) ) {
		push( @to_run, '--options', $opts{options} );
	}

	if ( defined( $opts{tags} ) ) {
		push( @to_run, '--tags', $opts{tags} );
	}

	foreach (@to_submit) {
		system( @to_run, $_ );
	}
}

=head2 timestamp

Creates a timestamp to be used with submit.

=cut

sub timestamp {
	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime;
	$year += 1900;
	$mon++;
	if ( $sec < 10 ) {
		$sec = '0' . $sec;
	}
	if ( $min < 10 ) {
		$min = '0' . $min;
	}
	if ( $hour < 10 ) {
		$hour = '0' . $hour;
	}
	if ( $mon < 10 ) {
		$mon = '0' . $mon;
	}
	if ( $mday < 10 ) {
		$mday = '0' . $mday;
	}

	return $mon . '-' . $mday . '-' . $year . ' ' . $hour . ':' . $min . ':' . $sec;
}

=head2 shuffle

Performa a Fisher Yates shuffle on the passed array ref.

=cut

sub shuffle {
	my $self  = shift;
	my $array = shift;
	my $i;
	for ( $i = @$array; --$i; ) {
		my $j = int rand( $i + 1 );
		next if $i == $j;
		@$array[ $i, $j ] = @$array[ $j, $i ];
	}
	return $array;
}

=head1 AUTHOR

Zane C. Bowers-Hadley, C<< <vvelox at vvelox.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-cape-utils at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=CAPE-Utils>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CAPE::Utils


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=CAPE-Utils>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/CAPE-Utils>

=item * Search CPAN

L<https://metacpan.org/release/CAPE-Utils>

=head * Git

L<git@github.com:VVelox/CAPE-Utils.git>

=item * Web

L<https://github.com/VVelox/CAPE-Utils>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2022 by Zane C. Bowers-Hadley.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

1;    # End of CAPE::Utils
