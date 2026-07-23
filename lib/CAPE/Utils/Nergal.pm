package CAPE::Utils::Nergal;

use 5.006;
use strict;
use warnings;
use JSON                 qw( decode_json encode_json );
use CAPE::Utils          ();
use File::Slurp          qw( read_file );
use Sys::Hostname        qw( hostname );
use File::Temp           qw( tempfile );
use File::Copy           qw( move );
use File::Basename       qw( dirname );
use Digest::SHA          ();
use Digest::MD5          ();
use CAPE::Utils::LogDrek qw( log_drek );

=pod

=head1 NAME

CAPE::Utils::Nergal - Transport agnostic backend for the nergal handler.

=head1 VERSION

Version 0.1.0

=cut

our $VERSION = '0.1.0';

=head1 SYNOPSIS

    use CAPE::Utils::Nergal ();

    my $submitter = CAPE::Utils::Nergal->new;

    # driven from a Mojolicious handler...
    my $result = $submitter->receive(
        remote_ip => $c->tx->original_remote_address,
        apikey    => $c->param('apikey'),
        raw_json  => $c->param('json'),
        upload    => $c->param('filename'),
        oversized => $c->req->is_limit_exceeded,
    );
    $c->render( text => $result->{body}, status => $result->{status} );

=head1 DESCRIPTION

This holds the logic previously living inside the C<the_stuff> sub in
C<nergal>. It is deliberately free of any Mojolicious dependency so
the receive pipeline can be unit tested and reused from other front ends (for
example a CGI wrapper).

The only piece of the transport that leaks in is the upload object handed to
L</receive>. It is duck typed and only needs to provide C<filename>, C<size>,
C<slurp> and C<move_to>, which both L<Mojo::Upload> and test doubles satisfy.

=head1 INCOMING DIR STRUCTURE

The following directories are used under the incoming directory.

    sha256
    json
    name_to_sha256
    task_to_json
    tmp

"tmp" is where the file is written to first to get the checksum.

"sha256" is where it is moved to after we have the checksum if it does not
already exist.

"json" is where the incoming JSON is written to based on filename.

"name_to_sha256" contains links from incoming filename to the sha256 in
question. If it already exists it is updated to the newest one.

"task_to_json" contains links from the task name to the JSON it is for.

=head1 METHODS

=head2 new

Initiates the object. All arguments are optional and taken as a hash.

    - ini :: Path to the INI config file to pass to L<CAPE::Utils>. If undef
        the L<CAPE::Utils> default is used.

    - incoming :: The incoming directory. Normally left undef as L</receive>
        fills it in from the config, but may be set directly when calling
        L</check_dirs> on its own.

    my $submitter = CAPE::Utils::Nergal->new( ini => '/path/to/config.ini' );

=cut

sub new {
	my ( $class, %opts ) = @_;

	my $self = {
		ini          => $opts{ini},
		incoming     => $opts{incoming},
		tracking_int => 0,
	};

	return bless $self, $class;
} ## end sub new

# thin wrapper so every log line from here is emitted under the nergal ident
sub _log_drek {
	my ( $level, $message, $tracking_int ) = @_;

	return log_drek( $level, $message, $tracking_int, 'nergal' );
}

=head2 check_dirs

Ensures the incoming directory and its required sub directories all exist and
are writable. Dies with a descriptive message on the first problem found.
C<< $self->{incoming} >> must be set, which L</receive> does from the config.

    eval { $submitter->check_dirs; };
    if ($@) { ... }

=cut

sub check_dirs {
	my ($self) = @_;

	my $incoming = $self->{incoming};

	if ( !-d $incoming ) {
		die 'incoming directory, "' . $incoming . '", does not exist';
	} elsif ( !-w $incoming ) {
		die 'incoming directory, "' . $incoming . '", is not writable';
	}

	foreach my $subdir (qw( sha256 json name_to_sha256 task_to_json tmp )) {
		my $path = $incoming . '/' . $subdir;
		if ( !-d $path ) {
			die 'incoming ' . $subdir . ' directory, "' . $path . '", does not exist';
		} elsif ( !-w $path ) {
			die 'incoming ' . $subdir . ' directory, "' . $path . '", is not writable';
		}
	}

	return 1;
} ## end sub check_dirs

=head2 checksums

Returns a hashref of lowercase hex checksums for the passed file path.

    my $sums = $submitter->checksums($path);
    # { sha256 => '...', sha1 => '...', md5 => '...' }

=cut

sub checksums {
	my ( $self, $path ) = @_;

	open( my $md5_fh, '<', $path ) or die( 'Failed to open "' . $path . '" for md5... ' . $! );
	binmode($md5_fh);
	my $md5 = Digest::MD5->new->addfile($md5_fh)->hexdigest;
	close($md5_fh);

	return {
		sha256 => Digest::SHA->new(256)->addfile($path)->hexdigest,
		sha1   => Digest::SHA->new(1)->addfile($path)->hexdigest,
		md5    => $md5,
	};
} ## end sub checksums

=head2 receive

Runs the full submission pipeline for a single incoming request and returns a
hashref describing the response to send.

    my $result = $submitter->receive(%opts);
    # { status => 200, body => "Submitted as task ID 5\n" }

Arguments are taken as a hash.

    - remote_ip :: The remote IP of the submitter.

    - apikey :: The submitted API key, or undef.

    - raw_json :: The raw value of the 'json' submission param, or undef.

    - upload :: The uploaded file object (L<Mojo::Upload> or a compatible
        object supporting filename/size/slurp/move_to), or undef.

    - oversized :: Boolean, true if the request exceeded the size limit. In the
        Mojolicious front end this comes from C<< $c->req->is_limit_exceeded >>.

All activity is logged via L<CAPE::Utils::LogDrek/log_drek>. The response body
and status mirror the original script for each outcome.

Should CAPE create multiple tasks for the submission, the body becomes
C<Submitted as task IDs 1,2,3> style, C<< .cape_submit.task >> holds the IDs
joined via ',', and a task_to_json link is created for each ID.

=cut

sub receive {
	my ( $self, %opts ) = @_;

	my $remote_ip = $opts{remote_ip};
	my $apikey    = $opts{apikey};

	my $tracking = $self->{tracking_int};
	$self->{tracking_int}++;

	# log the connection
	my $message = 'Started. Remote IP: ' . $remote_ip . '  API key: ';
	if ( defined($apikey) ) {
		$message = $message . $apikey;
	} else {
		$message = $message . 'undef';
	}
	_log_drek( 'info', $message, $tracking );

	my $cape_util;
	eval { $cape_util = CAPE::Utils->new( $self->{ini} ); };
	if ($@) {
		_log_drek( 'err', $@ );
		return { status => 400, body => "Error... please see syslog\n" };
	}

	my $incoming = $cape_util->{config}->{_}->{incoming};
	$self->{incoming} = $incoming;

	eval { $self->check_dirs; };
	if ($@) {
		_log_drek( 'err', $@, $tracking );
		return { status => 400, body => "Error... please see syslog\n" };
	}

	my ( $temp_fh, $temp_filename ) = tempfile( 'DIR' => $incoming . '/tmp' );

	my $allow_remote;
	eval { $allow_remote = $cape_util->check_remote( apikey => $apikey, ip => $remote_ip ); };
	if ($@) {
		_log_drek( 'err', $@, $tracking );
		return { status => 400, body => "Error... please see syslog\n" };
	}
	if ( !$allow_remote ) {
		_log_drek( 'info', 'API key or IP not allowed', $tracking );
		return { status => 403, body => "IP not allowed or invalid API key\n" };
	}

	if ( $opts{oversized} ) {
		_log_drek( 'err', 'Log size exceeded', $tracking );
		return { status => 400, body => 'File is too big.' };
	}

	my $file = $opts{upload};
	if ( !$file ) {
		_log_drek( 'err', 'No file specified', $tracking );
		return { status => 400, body => 'No file specified' };
	}

	# initial filename bits
	my $name      = $file->filename;
	my $size      = $file->size;
	my $orig_name = $name;
	$name =~ s/\///;
	my $json_filename = $incoming . '/json/' . $name;

	# if size is 10, test if the contents are a test ping packet
	if ( $size == 10 ) {
		my $file_data = $file->slurp;
		if ( $file_data =~ /1234567890/ ) {
			_log_drek( 'info', 'got ping test, size=10 payload=01234567890', $tracking );
			return { status => 200, body => "TEST RECIEVED\n" };
		}
	}

	# get the json metadata info
	my $raw_json = $opts{raw_json};
	my $json;
	eval { $json = decode_json($raw_json); };
	if ($@) {
		_log_drek( 'err', 'json param decode error: ' . $@ );
		$json = {};
	}

	# add initial relevant submission data
	$json->{cape_submit} = {
		orig_name => $orig_name,
		name      => $name,
		apikey    => $apikey,
		remote_ip => $remote_ip,
		size      => $size,
		time      => time,
		host      => hostname,
	};

	# copy it into place
	# save it here for getting SHA256 checksum
	$file->move_to($temp_filename);
	my $checksums = $self->checksums($temp_filename);
	$json->{'cape_submit'}{'sha256'} = $checksums->{sha256};
	_log_drek( 'info', 'SHA256: ' . $json->{'cape_submit'}{'sha256'}, $tracking );
	$json->{'cape_submit'}{'sha1'} = $checksums->{sha1};
	_log_drek( 'info', 'SHA1: ' . $json->{'cape_submit'}{'sha1'}, $tracking );
	$json->{'cape_submit'}{'md5'} = $checksums->{md5};
	_log_drek( 'info', 'MD5: ' . $json->{'cape_submit'}{'md5'}, $tracking );

	my $sha256_filename = $incoming . '/sha256/' . $json->{'cape_submit'}{'sha256'};
	my $name_filename   = $incoming . '/name_to_sha256/' . $name;
	# If it has already been received, we can skip this step and just unlink it.
	if ( !-f $sha256_filename ) {
		move( $temp_filename, $sha256_filename );
	} else {
		unlink($temp_filename);
	}
	# make sure it is always linked to the newest one if it is resubmitted
	if ( -e $name_filename ) {
		unlink($name_filename);
	}
	symlink( $sha256_filename, $name_filename );

	# log incoming file
	_log_drek(
		'info',
		'Got File... size=' . $size . ' filename="' . $name . '" sha256="' . $json->{'cape_submit'}{'sha256'} . '"',
		$tracking
	);

	# get some info for logging purposes
	# done this way for the purpose of not having to constantly check if something is undef
	my %additional_info;
	$additional_info{src_ip}       = $json->{'src_ip'};
	$additional_info{src_port}     = $json->{'src_port'};
	$additional_info{dest_ip}      = $json->{'dest_ip'};
	$additional_info{dest_port}    = $json->{'dest_port'};
	$additional_info{proto}        = $json->{'proto'};
	$additional_info{app_proto}    = $json->{'app_proto'};
	$additional_info{flow_id}      = $json->{'flow_id'};
	$additional_info{http_host}    = $json->{'http'}{'hostname'};
	$additional_info{http_url}     = $json->{'http'}{'url'};
	$additional_info{http_method}  = $json->{'http'}{'method'};
	$additional_info{http_proto}   = $json->{'http'}{'protocol'};
	$additional_info{http_status}  = $json->{'http'}{'status'};
	$additional_info{http_ctype}   = $json->{'http'}{'http_content_type'};
	$additional_info{http_ua}      = $json->{'http'}{'http_user_agent'};
	$additional_info{det_sub_type} = $json->{'http'}{'http_method'};
	$additional_info{src_host} = $json->{'suricata_extract_submit'}{'host'} // $json->{'lilith_cape_submit'}{'host'};

	# set the value for anything not defined to undef for the purpose of logging
	# this will avoid perl from throwing errors about undef used in cating
	foreach my $item ( keys(%additional_info) ) {
		if ( !defined( $additional_info{$item} ) ) {
			$additional_info{$item} = 'undef';
		}
	}
	$json->{det_sub_type} = $additional_info{det_sub_type};

	# log additional info
	_log_drek( 'info', 'Source Host: ' . $additional_info{src_host},         $tracking );
	_log_drek( 'info', 'Submission Type: ' . $additional_info{det_sub_type}, $tracking );
	_log_drek(
		'info',
		'proto='
			. $additional_info{proto}
			. ' src_ip='
			. $additional_info{src_ip}
			. ' src_port='
			. $additional_info{src_port}
			. ' dest_ip='
			. $additional_info{dest_ip}
			. ' dest_port='
			. $additional_info{dest_port}
			. ' flow_id='
			. $additional_info{flow_id},
		$tracking
	);
	if ( $additional_info{app_proto} eq 'http' ) {
		_log_drek( 'info', $additional_info{http_proto} . ' ' . $additional_info{http_host}, $tracking );
		_log_drek(
			'info',
			$additional_info{http_method} . ' ' . $additional_info{http_status} . ' ' . $additional_info{http_url},
			$tracking
		);
		_log_drek( 'info', 'useragent: ' . $additional_info{http_ua}, $tracking );
	} else {
		_log_drek( 'info', 'App Proto: ' . $additional_info{app_proto}, $tracking );
	}

	# finally submit it
	my $results;
	eval { $results = $cape_util->submit( items => [$name_filename], quiet => 1, ); };
	if ($@) {
		_log_drek( 'err', '$cape_util->submit( items => ["' . $name_filename . '"], quiet => 1, );  ... ' . $@,
			$tracking );
		return { status => 400, body => "Error... please see syslog\n" };
	}

	# can't continue if submission failed
	my @submitted = keys( %{$results} );
	if ( !defined( $submitted[0] ) ) {
		_log_drek( 'err', 'Submitting "' . $name_filename . '" failed', $tracking );
		return { status => 400, body => "Submission failed\n" };
	}

	# log the submission... the task value may be a single ID or several joined via ','
	my $task_value = $results->{ $submitted[0] };
	my @task_ids   = split( /,/, $task_value );
	my $id_wording = defined( $task_ids[1] ) ? 'task IDs' : 'task ID';
	_log_drek( 'info', 'Submitting "' . $name . '" submitted as ' . $task_value, $tracking );
	my $response = { status => 200, body => 'Submitted as ' . $id_wording . ' ' . $task_value . "\n" };
	$json->{cape_submit}{task} = $task_value;

	# write out the json containing the submission info
	eval { $self->_write_json( $json_filename, $json ); };
	if ($@) {
		_log_drek( 'err', 'Failed to write submission data JSON out to "' . $json_filename . '"... ' . $@ );
	} else {
		_log_drek( 'info', 'Wrote submission data JSON out to "' . $json_filename . '"', $tracking );
		eval { $self->_link_task_to_json( $task_value, $json_filename ); };
		if ($@) {
			_log_drek( 'err', $@, $tracking );
		}
	}

	return $response;
} ## end sub receive

# atomically write $json (a hashref) out to $file as JSON, so nothing can observe
# a half written file. A temp file is written in the same directory and renamed
# into place, which is atomic on the one filesystem the incoming dir lives on.
sub _write_json {
	my ( $self, $file, $json ) = @_;

	my ( $fh, $tmp ) = tempfile( DIR => dirname($file) );
	print {$fh} encode_json($json) . "\n";
	close($fh);
	chmod( 0644, $tmp );

	if ( !rename( $tmp, $file ) ) {
		my $err = $!;
		unlink($tmp);
		die 'Failed to rename "' . $tmp . '" to "' . $file . '"... ' . $err;
	}

	return;
} ## end sub _write_json

# create, or refresh, the task_to_json/<task> symlink pointing at $json_file.
# $task may be several task IDs joined via ',', in which case each ID gets a link.
# Dies if the path exists and is not a symlink, as that needs human intervention.
sub _link_task_to_json {
	my ( $self, $task, $json_file ) = @_;

	foreach my $task_id ( split( /,/, $task ) ) {
		my $link = $self->{incoming} . '/task_to_json/' . $task_id;

		if ( -e $link && !-l $link ) {
			die 'Link to submission data JSON, "' . $link . '", exists on FS and is not a link';
		}

		if ( -l $link ) {
			unlink($link) || die( 'Failed to unlink "' . $link . '"' );
		}

		symlink( $json_file, $link )
			|| die( 'Failed to link "' . $json_file . '" to "' . $link . '"' );
	} ## end foreach my $task_id ( split( /,/, $task ) )

	return;
} ## end sub _link_task_to_json

=head2 resub

Resubmit a sample that was originally submitted via nergal, located
by exactly one of two keys.

    my $result = $submitter->resub( name => $name );
    my $result = $submitter->resub( task => $task_id );

    - name :: The incoming name to resubmit. As the JSON store is keyed by name
        and overwritten per name, this targets the most recent submission made
        under that name.

    - task :: A task ID to resubmit. Resolved via the task_to_json link to the
        exact incoming JSON that task was linked to. For a submission CAPE
        fanned out into multiple tasks, any one of those task IDs works.

The sample itself is always located via C<< .cape_submit.sha256 >> in the
JSON, which points at the content addressed C<sha256/> store, so it is the
correct bytes even if the name has since been relinked to a different sample.

Once resubmitted the previous C<< .cape_submit.time >> is pushed onto
C<< .cape_submit.time_orig >> and C<< .cape_submit.time >> is set to now, then
the previous C<< .cape_submit.task >> is pushed onto C<< .cape_submit.task_orig >>
and C<< .cape_submit.task >> is set to the new task ID. The JSON is updated
atomically and a new task_to_json link is created for the new task ID. Nothing
is mutated if the resubmission itself fails.

Dies on any problem (missing/dangling entry, missing sample, failed
resubmission). On success returns a hashref.

    {
        name     => the incoming name,
        json     => the incoming JSON path that was updated,
        sha256   => the sample sha256,
        old_task => the task ID prior to resubmission,
        task     => the new task ID,
    }

Task values may be several IDs joined via ',' if CAPE fanned the submission in
question out into multiple tasks.

=cut

sub resub {
	my ( $self, %opts ) = @_;

	if ( !defined( $opts{name} ) && !defined( $opts{task} ) ) {
		die 'resub requires one of: name, task';
	}
	if ( defined( $opts{name} ) && defined( $opts{task} ) ) {
		die 'resub takes only one of: name, task';
	}

	my $cape_util = CAPE::Utils->new( $self->{ini} );
	my $incoming  = $cape_util->{config}->{_}->{incoming};
	$self->{incoming} = $incoming;

	# locate the canonical incoming JSON path from whichever key was given
	my $json_file;
	if ( defined( $opts{name} ) ) {
		my $name = $opts{name};
		$name =~ s/\///;    # mojo stores names with a single leading slash stripped
		$json_file = $incoming . '/json/' . $name;
		if ( !-f $json_file ) {
			die 'no incoming JSON for name "' . $name . '" at "' . $json_file . '"';
		}
	} else {
		my $link = $incoming . '/task_to_json/' . $opts{task};
		if ( !-e $link ) {
			die 'no task_to_json link for task "' . $opts{task} . '"';
		}
		$json_file = readlink($link);
		if ( !defined($json_file) || !-f $json_file ) {
			die 'task_to_json link for task "' . $opts{task} . '" is dangling';
		}
	} ## end else [ if ( defined( $opts{name} ) ) ]

	my $json;
	eval { $json = decode_json( read_file($json_file) ); };
	if ($@) {
		die 'failed to read/parse "' . $json_file . '"... ' . $@;
	}

	# as json/<name> is mutable, a task ID can resolve to a JSON that was since
	# overwritten by a different sample reusing that name... guard against it
	# task values may be several IDs joined via ',', so split before comparing
	if ( defined( $opts{task} ) ) {
		my @known_tasks;
		if ( defined( $json->{cape_submit}{task} ) ) {
			push( @known_tasks, split( /,/, $json->{cape_submit}{task} ) );
		}
		if ( defined( $json->{cape_submit}{task_orig} ) ) {
			foreach my $old_task_value ( @{ $json->{cape_submit}{task_orig} } ) {
				if ( defined($old_task_value) ) {
					push( @known_tasks, split( /,/, $old_task_value ) );
				}
			}
		}
		my $found = grep { $_ eq $opts{task} } @known_tasks;
		if ( !$found ) {
			my $name = defined( $json->{cape_submit}{name} ) ? $json->{cape_submit}{name} : 'undef';
			die 'JSON for task "'
				. $opts{task}
				. '" was overwritten by a newer submission of "'
				. $name
				. '"... resubmit by name if that is intended';
		}
	} ## end if ( defined( $opts{task} ) )

	# locate the sample via the content addressed sha256 store
	my $sha256 = $json->{cape_submit}{sha256};
	if ( !defined($sha256) ) {
		die '"' . $json_file . '" has no .cape_submit.sha256';
	}
	my $sample = $incoming . '/sha256/' . $sha256;
	if ( !-f $sample ) {
		die 'sample missing at "' . $sample . '"';
	}

	# resubmit the sample... bail before mutating anything if this fails
	my $results;
	eval { $results = $cape_util->submit( items => [$sample], quiet => 1 ); };
	if ($@) {
		die 'resubmission of "' . $sample . '" failed... ' . $@;
	}
	my @tasks    = values( %{$results} );
	my $new_task = $tasks[0];
	if ( !defined($new_task) ) {
		die 'resubmission of "' . $sample . '" returned no task ID';
	}

	my $old_task = $json->{cape_submit}{task};

	# record history, then update... order matters
	push( @{ $json->{cape_submit}{time_orig} }, $json->{cape_submit}{time} );
	$json->{cape_submit}{time} = time;
	push( @{ $json->{cape_submit}{task_orig} }, $json->{cape_submit}{task} );
	$json->{cape_submit}{task} = $new_task;

	$self->_write_json( $json_file, $json );
	$self->_link_task_to_json( $new_task, $json_file );

	_log_drek( 'info',
			  'resubmitted "'
			. $json_file
			. '" as task '
			. $new_task
			. ' (was '
			. ( defined($old_task) ? $old_task : 'undef' )
			. ')' );

	return {
		name     => $json->{cape_submit}{name},
		json     => $json_file,
		sha256   => $sha256,
		old_task => $old_task,
		task     => $new_task,
	};
} ## end sub resub

=head1 AUTHOR

Zane C. Bowers-Hadley, C<< <vvelox at vvelox.net> >>

=cut

1;
