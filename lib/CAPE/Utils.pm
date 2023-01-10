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
use Data::Dumper;
use JSON::Path;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse    = 1;

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

Set one or more pending tasks to failed.

The following options are also supported.

    - where :: Additional SQL where statements to add. Something must
               be specified for this, unless fail_all in the config is
               true. Otherwise this method will die.

    my $rows=$cape_util->fail( pending_columns=>'id,package');

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

Get pending count pending tasks.

    my $count=$cape_util->get_pending_count;

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

Returns a array ref of hash refs of rows from the tasks table where the
status is set to pending.

    use Data::Dumper;

    my $running=$cape_utils->get_running;
    print Dumper($running);

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

Get pending count running tasks.

    my $count=$cape_util->get_running_count;

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

# =head2 mangle

# Manges the specified report JSON. Requires either file or string
# to be defined.

#     - file :: The specified file to operate on.
#       - Default :: undef

#     - string :: If specified, this is parsed as JSON.
#       - Default :: undef

#     - rules :: A array ref of rules to process.
#       - Default :: undef

# =cut

# sub mangle {
# 	my ( $self, %opts ) = @_;

# 	# make sure we have a file or string specified
# 	if ( defined( $opts{file} ) && defined( $opts{string} ) ) {
# 		die('Both file and string are defined. Must be one or the other.');
# 	}

# 	# check to see if we have a rules array and see if it is sane
# 	if ( !defined( $opts{rules} ) ) {
# 		die('rules is not defined');
# 	}
# 	elsif ( ref( $opts{rules} ) ne 'ARRAY' ) {
# 		die( 'rules is not a array, but a ' . ref( $opts{rules} ) );
# 	}
# 	else {
# 		my $int = 0;
# 		while ( defined( $opts{rules}[$int] ) ) {

# 			# make sure the specified rule is a hash
# 			if ( ref( $opts{rules}[$int] ) ne 'HASH' ) {
# 				die(      '$rules['
# 						. $int
# 						. '] is not a hash, but a '
# 						. ref( $opts{rules}[$int] ) . '... '
# 						. Dumper( $opts{rules}[$int] ) );
# 			}

# 			# make sure we have a action
# 			if ( !defined( $opts{rules}[$int]{action} ) ) {
# 				die( '$rules[' . $int . '] lacks a action key... ' . Dumper( $opts{rules}[$int] ) );
# 			}

# 			# make sure the action is valid
# 			if (   $opts{rules}[$int]{action} ne 'remove'
# 				&& $opts{rules}[$int]{action} ne 'remove_all'
# 				&& $opts{rules}[$int]{action} ne 'set' )
# 			{
# 				die(      '$rules['
# 						. $int
# 						. ']{action}="'
# 						. $opts{rules}[$int]{action}
# 						. '" is not a known action...'
# 						. Dumper( $opts{rules}[$int] ) );
# 			}

# 			# if action is set, make sure we have set
# 			if ( $opts{rules}[$int]{action} eq 'set' && !defined( $opts{rules}[$int]{set} ) ) {
# 				die(      '$rules['
# 						. $int
# 						. ']{action} is set to set, but no set key is defined'
# 						. Dumper( $opts{rules}[$int] ) );
# 			}

# 			# if action is set, make sure set has some of the expected keys
# 			if (
# 				$opts{rules}[$int]{action} eq 'set'
# 				&& (   !defined( $opts{rules}[$int]{set}{'confidence'} )
# 					|| !defined( $opts{rules}[$int]{set}{'severity'} )
# 					|| !defined( $opts{rules}[$int]{set}{'weight'} ) )
# 				)
# 			{
# 				die(      '$rules['
# 						. $int
# 						. ']{action} is set to set, the set hash is lacking any confidence, severity, or weight'
# 						. Dumper( $opts{rules}[$int] ) );
# 			}

# 			# make sure we have atleast one one known matching type
# 			if (
# 				!defined( $opts{rules}[$int]{'package'})
# 				|| !defined( $opts{rules}[$int]{'sig_name'} )
# 				|| !defined( $opts{rules}[$int]{'data_count'} )
# 				|| !defined( $opts{rules}[$int]{'jsonpath'} )
# 				|| !defined( $opts{rules}[$int]{'jsonpath_sig'} )
# 				)
# 			{
# 				die(      '$rules['
# 						. $int
# 						. '] lacks anything to use for matching'
# 						. Dumper( $opts{rules}[$int] ) );
# 			}

# 			$int++;
# 		}
# 	}

# 	# if we have a file, read it in
# 	if ( defined( $opts{file} ) ) {
# 		if ( !-f $opts{file} ) {
# 			die( '"' . $opts{file} . '" is not a file' );
# 		}
# 		elsif ( !-r $opts{file} ) {
# 			die( '"' . $opts{file} . '" is not readable' );
# 		}

# 		# read it into $opts{string} so it is in the same variable regardless
# 		$opts{string} = read_file( $opts{file} );
# 	}

# 	# decode the json and check to see if we have a few basic exepected keys
# 	my $json = decode_json( $opts{string} );
# 	if (   defined( $json->{info}{package} )
# 		|| !defined( $json->{signatures} )
# 		|| !defined( $json->{CAPE} ) )
# 	{
# 		die('The JSON does not appear to be a CAPE report');
# 	}

# 	# remove this to save a bit of space while we are processing it
# 	delete($opts{string});

# 	# will be used as key name for 
# 	my $delete_string=rand.rand.rand.rand;

# 	# start processing each sig
# 	my $sigs_int=0;
# 	while (defined( $json->{signatures}[$sigs_int] )) {
# 		my $rules_int=0;

# 		my @matched;

# 		my @new_sigs;

# 		while ( defined( $opts{rules}[$rules_int] ) ) {
# 			my @truths;

# 			# runs the package match check
# 			if (defined $opts{rules}[$rules_int]{package}  ) {
# 				my $regex=$opts{rules}[$rules_int]{package};
# 				if ($json->{info}{package} =~ /$regex/) {
# 					push(@truths, 1);
# 				}else {
# 					push(@truths, 0);
# 				}
# 			}

# 			# runs the sig name match check
# 			if (defined $opts{rules}[$rules_int]{sig_name}  ) {
# 				my $regex=$opts{rules}[$rules_int]{sig_name};
# 				if ($json->{signatures}[$sigs_int]{name} =~ /$regex/) {
# 					push(@truths, 1);
# 				}else {
# 					push(@truths, 0);
# 				}
# 			}

# 			# runs the data count match check
# 			if (defined $opts{rules}[$rules_int]{data_count}  ) {
# 				if($opts{rules}[$rules_int]{data_count} =~ /^\![0-9]+$/) {
# 					if ( $opts{rules}[$rules_int]{data_count} != $#{ $json->{signatures}[$sigs_int]{data} } ){
# 						push(@truths, 1);
# 					}else {
# 						push(@truths, 0);
# 					}
# 				}elsif($opts{rules}[$rules_int]{data_count} =~ /^\>\=[0-9]+$/) {
# 					if ( $opts{rules}[$rules_int]{data_count} >= $#{ $json->{signatures}[$sigs_int]{data} } ){
# 						push(@truths, 1);
# 					}else {
# 						push(@truths, 0);
# 					}
# 				}elsif($opts{rules}[$rules_int]{data_count} =~ /^\>[0-9]+$/) {
# 					if ( $opts{rules}[$rules_int]{data_count} > $#{ $json->{signatures}[$sigs_int]{data} } ){
# 						push(@truths, 1);
# 					}else {
# 						push(@truths, 0);
# 					}
# 				}elsif($opts{rules}[$rules_int]{data_count} =~ /^\<\=[0-9]+$/) {
# 					if ( $opts{rules}[$rules_int]{data_count} <= $#{ $json->{signatures}[$sigs_int]{data} } ){
# 						push(@truths, 1);
# 					}else {
# 						push(@truths, 0);
# 					}
# 				}elsif($opts{rules}[$rules_int]{data_count} =~ /^\<[0-9]+$/) {
# 					if ( $opts{rules}[$rules_int]{data_count} < $#{ $json->{signatures}[$sigs_int]{data} } ){
# 						push(@truths, 1);
# 					}else {
# 						push(@truths, 0);
# 					}
# 				}elsif($opts{rules}[$rules_int]{data_count} =~ /^[0-9]+$/) {
# 					if ( $opts{rules}[$rules_int]{data_count} = $#{ $json->{signatures}[$sigs_int]{data} } ){
# 						push(@truths, 1);
# 					}else {
# 						push(@truths, 0);
# 					}
# 				}
# 			}

# 			# handles the json path check
# 			if (defined( $opts{rules}[$rules_int]{jsonpath} ) ) {
				
# 			}

# 			$rules_int++;
# 		}


# 		$sigs_int++;
# 	}
# }

=head2 search

Searches the list of tasks. By default everything will be return ed.

    - where :: Additional SQL where statements to use for searching.
               May not contain a ';'.
      - Default :: undef

Addtionally there are also helpers for searching. These may not contain either a /\'/
or a /\\/. They will be joined via and.

The following are handled as a simple equality.

    - timeout
    - memory
    - enforce_timeout
    - timedout

The following are numeric. Each one may accept multiple
comma sperated values. The equalities =, >,>=, <=, and !
are supported. If no equality is specified, then = is used.

    - id
    - timeout
    - priority
    - dropped_files
    - running_processes
    - api_calls
    - domains
    - signatures_total
    - signatures_alert
    - files_written
    - registry_keys_modified
    - crash_issues
    - anti_issues
    - sample_id
    - machine_id

    # will result in id >= 3 and id < 44
    id => '>=3,<44'

    # either of these will be id = 4
    id => '=4'
    id => '4'

The following are string items. As is, they
are evaluated as a simple equality. If ending with
ending in '_like', they will be evaluated as a like.

    - target
    - category
    - custom
    - machine
    - package
    - route
    - tags_tasks
    - options
    - platform

    # becomes... target = 'foo'
    target => 'foo'

    # becomes... target like 'foo%'
    target_like => 'foo%'

=cut

sub search {
	my ( $self, %opts ) = @_;

	if ( defined( $opts{where} ) && $opts{where} =~ /\;/ ) {
		die '$opts{where},"' . $opts{where} . '", contains a ";"';
	}

	#
	# make sure all the set variables are not dangerous or potentially dangerous
	#

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
				elsif ( $arg =~ /^\=[0-9]+$/ ) {
					$arg =~ s/^\=//;
					$sql = $sql . " and " . $item . " <= '" . $arg . "'";
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

Creates a timestamp to be used with utils/submit. localtime
is used to get the current time.

    print $cape_util->timestamp."\n";

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

# =head1 Mangle Rules

# First it figures out how to match the items based on the keys configured
# for that rule. If all specified matches are true, then it performs
# the specified action.

# If the package used is pdf and the signature in question is dead connect, drop
# that signature and recompute.

#     ruless=>[
#             {
#                 package=>'^pdf$'
#                 sig_name=>'^dead_connect$'
#                 action=>'remove',
#             }
#         ],

# =head2 Matching

# The ones used for matching are as below.

# =over 4

# =item package

# A regexp for matching $json->{info}{package}.

#     package=>'^pdf$'

# =item sig_name

# Matches the hash value 'name' from a signature.

#     sig_name=>'^dead_connect$'

# =item data_count

# Number of entries in the data array for a sig. 0 means it is undef
# or non are present. May start with <, <=, >, >=, or ! for numeric
# equality.

#     data_count=20

# =item jsonpath

# Uses L<JSON::Path> to grab a path and then process it.

# For if a single value is returned(and not a hash or array),
# the matching is evaluated as normal.

# If the value returned is a array, each item in the array
# will be evaulauted. The path_match variable is used for
# controlling it expects the value to all return true, any
# to return true, or none of them to return true. To match
# both need to be true. If that is not clear, see the
# tables below for a few examples.

#     All, All
#     | Paths | Values | Result |
#     |-------|--------|--------|
#     | 0     | 0      | 0      |
#     | 1     | 0      | 0      |
#     | 0     | 1      | 0      |
#     | 1     | 1      | 1      |

#     Any, All
#     | Paths | Values | Result |
#     |-------|--------|--------|
#     | 00    | 0      | 0      |
#     | 01    | 0      | 0      |
#     | 01    | 1      | 1      |
#     | 11    | 0      | 0      |
#     | 11    | 1      | 1      |

#     All, Any
#     | Paths | Values | Result |
#     |-------|--------|--------|
#     | 0     | 00     | 0      |
#     | 01    | 0      | 0      |
#     | 01    | 1      | 1      |
#     | 11    | 0      | 0      |
#     | 11    | 1      | 1      |

#     Any, Any
#     | Paths | Values | Result |
#     |-------|--------|--------|
#     | 00    | 00     | 0      |
#     | 01    | 00     | 0      |
#     | 11    | 00     | 0      |
#     | 00    | 01     | 0      |
#     | 00    | 11     | 0      |
#     | 01    | 01     | 1      |
#     | 11    | 01     | 1      |
#     | 01    | 11     | 1      |
#     | 11    | 11     | 1      |

# If the value returned is a array, then this matching rules
# is considered false and no further processing is done.

# If values is not a array, it will be turned into one
# while processing. So "value=>'^pdf$'" would become
# "value=>['^pdf$']".

#     jsonpath=>{
#         path=>'.info.package',
#         type=>'regex',
#         value=>'^pdf$',
#         value_match=>'all'
#         path_match=>'all'
#     }

# If 'sub_path' is specified, first the path will be handled
# and then sub_path will be used against what is found.

#     jsonpath=>{
#         path=>'.info',
#         sub_path=>'.package',
#         type=>'regex',
#         value=>'^pdf$',
#         value_match=>'all'
#         path_match=>'all'
#     }

# The following types are supported. The default
# is 'eq'.

#     - regex :: Value will be evaluated as a regex.

#     - eq :: String equal.

#     - !eq :: String not equal.

#     - = :: Numeric equal.

#     - != :: Numeric not equal.

#     - > :: Numeric greater than.

#     - >= :: Numeric greater or equal to.

#     - < :: Numeric less than.

#     - <= :: Numeric less than or equal to.

#     - subnet :: Check if a subnet matches.

# The following matches are supported for both path
# and value matching. The default for both is 'all'.

#     - all :: All must match.

#     - any :: Any may match.

#     - none :: All must not match.

# =item jsonpath_sig

# Like jsonpath, but relative to the the sig.

# A single return is expected.

#     jsonpath_sig=>{
#         path=>'.name',
#         type=>'regex',
#         value=>'^dead_connect$'
#     }

# =back

# =head2 Actions

# Actions are specified via the key 'action'.

# =over 4

# =item remove

# Drops that sig.

# =item remove_all

# Drops all sigs.

# =item set

# Changes severity, weight, and/or confidence of a sig.

#     action=>'set',
#     action_data=>{ confidence=>50 },

# =back

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
