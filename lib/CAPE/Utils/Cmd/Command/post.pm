package CAPE::Utils::Cmd::Command::post;

use strict;
use warnings;
use parent 'CAPE::Utils::Cmd::Base';

our $VERSION = '0.1.0';

sub abstract {
	return 'perform the post actions for a run';
}

sub usage_desc {
	return '%c post [-d] -r ID

Performs the configured post actions for the specified run ID.
';
}

sub opt_spec {
	my ($class) = @_;
	return ( [ 'r=i', 'the run ID to post process' ],
			 ['d', 'describe the actions to be taken']
			 , $class->ini_opt, );
}

sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( !defined( $opt->{'r'} ) ) {
		$self->usage_error('No run ID specified via -r');
	}

	return;
}

sub execute {
	my ( $self, $opt, $args ) = @_;

	my $cape_utils=$self->cape_utils($opt->{'ini'});

	if ($opt->{'d'}) {
		print 'munge: '.$cape_utils->{'config'}{'_'}{'post_munge'}."\n";
		print 'post_link: '.$cape_utils->{'config'}{'_'}{'post_link'}."\n";
		print 'post_bin_rm: '.$cape_utils->{'config'}{'_'}{'post_bin_rm'}."\n";
		
		return;
	}
	
	$cape_utils->post( 'id' => $opt->{'r'} );

	return;
}

1;
