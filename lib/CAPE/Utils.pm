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

=cut

sub new {
	my $ini = $_[1];

	if ( !defined($ini) ) {
		$ini = '/usr/local/etc/cape_utils.ini';
	}

	my $base_config = {
		'_' => {
			dsn    => 'dbi:Pg:dbname=cape',
			user   => 'cape',
			pass   => '',
			base   => '/opt/CAPEv2/',
			poetry => 1,
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

=head2 get_pending_count

=cut

sub get_pending_count{
	my $self=$_[0];

	my $dbh=$self->connect;

	my $sth = $dbh->prepare("select * from tasks where status = 'pending'");
	$sth->execute;

	my $rows = $sth->rows;

	$sth->finish();
	$dbh->disconnect();

	return $rows;
};

=head2 get_pending

=cut

sub get_pending{
	my $self=$_[0];

	my $dbh=$self->connect;

	my $sth = $dbh->prepare("select * from tasks where status = 'pending'");
	$sth->execute;
	use Data::Dumper;
	my $row;
	while ($row = $sth->fetchrow_hashref) {
		print Dumper($row);
	}
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
