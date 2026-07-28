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
use File::Basename       qw( basename dirname );
use Cwd                  qw( abs_path );
use Socket               qw( inet_pton AF_INET AF_INET6 );
use POSIX                qw( strftime );
use Digest::SHA          ();
use Digest::MD5          ();
use CAPE::Utils::LogDrek qw( log_drek );

=pod

=head1 NAME

CAPE::Utils::Nergal - Transport agnostic backend for the nergal handler.

=head1 VERSION

Version 0.2.0

=cut

our $VERSION = '0.2.0';

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

=head2 parse_name

Parse the standard submission name format. This is the format
L<suricata_extract_submit> builds its names in and which other tools submitting
to nergal follow.

    <src_ip>-<src_port>-<dest_ip>-<dest_port>-<proto>-<sha1>-<slug>-<epoch>-<mime>

The mime has any '/' replaced with '_', so a name in this format never holds a
'/'.

    my $parsed = $submitter->parse_name($name);
    # {
    #     src_ip    => '192.168.14.42',
    #     src_port  => 80,
    #     dest_ip   => '192.168.14.2',
    #     dest_port => 60729,
    #     proto     => 'TCP',
    #     sha1      => '335835d5cc1cde63a8',
    #     slug      => 'vvelox',
    #     time      => 1780421209,
    #     timestamp => '2026-06-02T17:26:49Z',
    #     mime      => 'application_x-msdownload',
    # }

The name is split on '-' with a limit of 9, so the mime, the only field that
may hold a '-', keeps whatever it has. Every other field must be free of them,
the slug included.

Each field is then validated, and matching is all or nothing. Unless all nine
are present and valid, undef is returned rather than a partially filled hash,
so a name that is not in this format, such as one from a manual submission,
parses to nothing. A slug holding a '-' shifts every field after it and fails
validation, so it declines rather than mis-parsing.

    0 src_ip    :: A valid IPv4 or IPv6 address.
    1 src_port  :: An integer in the range 0 to 65535.
    2 dest_ip   :: A valid IPv4 or IPv6 address.
    3 dest_port :: An integer in the range 0 to 65535.
    4 proto     :: 'TCP' or 'UDP', matched without regard to case and
                   returned upper cased.
    5 sha1      :: Hex only, of any length. Upper, lower, or mixed case all
                   parse, and it is returned lower cased so it compares against
                   the checksums L</checksums> generates. Current submitters
                   put a full sha1 here, but older ones put the first 18
                   characters of the md5 instead and nothing marks which it is,
                   so no particular length is required and consumers should
                   compare it as a prefix against both digests.
    6 slug      :: Defined, not empty, and not all digits.
    7 time      :: A positive integer, taken as a UTC epoch.
    8 mime      :: The mime type with the '/' replaced by a '_', so it must
                   hold at least one '_'.

The epoch is always UTC. suricata_extract_submit builds it by handing the EVE
record's timestamp to C<< Time::Piece->strptime >> after stripping the
fractional seconds and offset, which interprets it as UTC. C<timestamp> is that
same instant rendered as an ISO 8601 UTC string for convenience.

=cut

# valid if the system can pack it as either family... inet_pton handles the full
# range of IPv6 forms, which is not worth hand rolling a regex for
sub _is_ip {
	my ($address) = @_;

	if ( !defined($address) || $address eq '' ) {
		return 0;
	}

	if ( defined( inet_pton( AF_INET, $address ) ) || defined( inet_pton( AF_INET6, $address ) ) ) {
		return 1;
	}

	return 0;
} ## end sub _is_ip

sub _is_port {
	my ($port) = @_;

	# \z rather than $, as $ would also match with a trailing newline on the end
	if ( !defined($port) || $port !~ /\A[0-9]{1,5}\z/ || $port > 65535 ) {
		return 0;
	}

	return 1;
} ## end sub _is_port

sub parse_name {
	my ( $self, $name ) = @_;

	if ( !defined($name) ) {
		return undef;
	}

	# limit of 9 so the mime keeps any '-' it holds... every other field must be
	# free of them, so anything past the ninth belongs to the mime
	my @fields = split( /-/, $name, 9 );
	if ( scalar(@fields) != 9 ) {
		return undef;
	}
	my ( $src_ip, $src_port, $dest_ip, $dest_port, $proto, $sha1, $slug, $epoch, $mime ) = @fields;

	if ( !_is_ip($src_ip) || !_is_ip($dest_ip) ) {
		return undef;
	}
	if ( !_is_port($src_port) || !_is_port($dest_port) ) {
		return undef;
	}
	# every one of these anchors with \z rather than $, as $ would also match with
	# a trailing newline on the end of the field
	if ( $proto !~ /\A(?:TCP|UDP)\z/i ) {
		return undef;
	}
	if ( $sha1 !~ /\A[0-9a-fA-F]+\z/ ) {
		return undef;
	}
	# an all digit slug is indistinguishable from a misplaced epoch
	if ( !defined($slug) || $slug eq '' || $slug =~ /\A[0-9]+\z/ ) {
		return undef;
	}
	if ( $epoch !~ /\A[0-9]+\z/ || $epoch <= 0 ) {
		return undef;
	}
	# the mime is the type with its '/' swapped for a '_', so it must hold one
	if ( $mime !~ /\A[A-Za-z0-9._+-]*_[A-Za-z0-9._+-]*\z/ ) {
		return undef;
	}

	return {
		src_ip    => $src_ip,
		src_port  => $src_port + 0,
		dest_ip   => $dest_ip,
		dest_port => $dest_port + 0,
		proto     => uc($proto),
		sha1      => lc($sha1),
		slug      => $slug,
		time      => $epoch + 0,
		timestamp => strftime( '%Y-%m-%dT%H:%M:%SZ', gmtime( $epoch + 0 ) ),
		mime      => $mime,
	};
} ## end sub parse_name

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

The C<json> body is optional. When the submitted name parses via L</parse_name>,
the submission is treated as a standard suricata_extract_submit one and the
fields recoverable from the name are filled in before the JSON is written out:
C<< .src_ip >>, C<< .src_port >>, C<< .dest_ip >>, C<< .dest_port >>, and
C<< .proto >> at the top level, plus C<< .suricata_extract_submit >>'s
C<filename>, C<slug>, C<sha1>, C<time>, C<timestamp>, and C<mime>. Anything the
submitter actually sent is never overwritten, and nothing is filled in at all
unless the name parses in full.

Only the file bit of the submitted name is used, via
L<File::Basename/basename>, as the name comes straight from the multipart
headers and may hold path separators. A name with nothing usable left after
that is rejected with a 400. C<< .cape_submit.orig_name >> still records the
name exactly as submitted.

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

	# The submitted name is whatever the client put in the multipart headers, so
	# it may hold path separators. Only the file bit of it is ever used, as
	# anything else would let a submitter walk out of the incoming dir and have
	# the JSON write, the unlink, and the symlink below all land elsewhere. The
	# name as submitted is still kept in full as .cape_submit.orig_name.
	# basename returns '/' as is, and leaves '.' and '..' alone, none of which are
	# a usable file name, so they are checked for rather than assumed away
	$name = basename($name);
	if ( $name eq '' || $name eq '.' || $name eq '..' || $name =~ m,/, ) {
		_log_drek( 'err', 'Submitted filename, "' . $orig_name . '", has no usable file name in it', $tracking );
		return { status => 400, body => "Invalid file name\n" };
	}

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

	# a JSON body is optional and some submitters send none... a top level that is
	# not a hash would blow up everything below, so treat it as nothing submitted
	if ( ref($json) ne 'HASH' ) {
		_log_drek( 'err', 'json param did not decode to a hash... ignoring it', $tracking );
		$json = {};
	}

	# Tools other than suricata_extract_submit submit using the same name format
	# but without the JSON body that normally carries the flow info and the slug.
	# When the name parses in full, treat it as a standard suricata_extract_submit
	# submission and fill in what the name gives us. Anything actually submitted
	# always wins, and a name that does not fully parse pads nothing at all.
	my $from_name = $self->parse_name($name);
	if ( defined($from_name) ) {
		foreach my $field (qw( src_ip src_port dest_ip dest_port proto )) {
			if ( !defined( $json->{$field} ) ) {
				$json->{$field} = $from_name->{$field};
			}
		}

		# the md5, sha256, host, to, and apikey the section normally holds are not
		# recoverable from the name, so only what is actually in it gets filled in
		my %from_name_section = (
			filename  => $name,
			slug      => $from_name->{slug},
			sha1      => $from_name->{sha1},
			time      => $from_name->{time},
			timestamp => $from_name->{timestamp},
			mime      => $from_name->{mime},
		);
		if ( !defined( $json->{suricata_extract_submit} ) ) {
			$json->{suricata_extract_submit} = {};
		}
		# leave it be if the submitter put something other than a hash there
		if ( ref( $json->{suricata_extract_submit} ) eq 'HASH' ) {
			foreach my $field ( keys(%from_name_section) ) {
				if ( !defined( $json->{suricata_extract_submit}{$field} ) ) {
					$json->{suricata_extract_submit}{$field} = $from_name_section{$field};
				}
			}
		}

		_log_drek( 'info',
			'Padded submission from name... slug="' . $from_name->{slug} . '" mime="' . $from_name->{mime} . '"',
			$tracking );
	} ## end if ( defined($from_name) )

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
	$additional_info{src_ip}    = $json->{'src_ip'};
	$additional_info{src_port}  = $json->{'src_port'};
	$additional_info{dest_ip}   = $json->{'dest_ip'};
	$additional_info{dest_port} = $json->{'dest_port'};
	$additional_info{proto}     = $json->{'proto'};
	$additional_info{app_proto} = $json->{'app_proto'};
	$additional_info{flow_id}   = $json->{'flow_id'};
	# the sub sections are pulled via a hashref that is only taken when the section
	# is actually there... dereferencing $json->{http} and friends directly would
	# autovivify them, leaving an empty section in the JSON that gets written out
	my $http = ref( $json->{'http'} ) eq 'HASH' ? $json->{'http'} : {};
	$additional_info{http_host}    = $http->{'hostname'};
	$additional_info{http_url}     = $http->{'url'};
	$additional_info{http_method}  = $http->{'method'};
	$additional_info{http_proto}   = $http->{'protocol'};
	$additional_info{http_status}  = $http->{'status'};
	$additional_info{http_ctype}   = $http->{'http_content_type'};
	$additional_info{http_ua}      = $http->{'http_user_agent'};
	$additional_info{det_sub_type} = $http->{'http_method'};

	my $suricata_section
		= ref( $json->{'suricata_extract_submit'} ) eq 'HASH' ? $json->{'suricata_extract_submit'} : {};
	my $lilith_section = ref( $json->{'lilith_cape_submit'} ) eq 'HASH' ? $json->{'lilith_cape_submit'} : {};
	$additional_info{src_host} = $suricata_section->{'host'} // $lilith_section->{'host'};

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
		# only the file bit is used, matching how receive stores it, so a name
		# holding path separators cannot be used to read outside the json dir
		my $name = basename( $opts{name} );
		if ( $name eq '' || $name eq '.' || $name eq '..' || $name =~ m,/, ) {
			die 'name "' . $opts{name} . '" has no usable file name in it';
		}
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

	# resubmit via the name_to_sha256 link rather than the content addressed
	# sha256 store... the sha256 store file is named after its hash, so CAPE would
	# record the hash as the filename. name_to_sha256/<name> is a symlink to the
	# same bytes but keeps the original submission name, so the resubmission
	# matches the original.
	my $sha256 = $json->{cape_submit}{sha256};
	if ( !defined($sha256) ) {
		die '"' . $json_file . '" has no .cape_submit.sha256';
	}
	my $sample_name = $json->{cape_submit}{name};
	if ( !defined($sample_name) ) {
		die '"' . $json_file . '" has no .cape_submit.name';
	}
	my $sample = $incoming . '/name_to_sha256/' . $sample_name;
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

=head1 RESULTS FETCHING

The results methods expose the detonation artifacts CAPEv2 writes under
C<< <base>/storage/analyses/<task_id>/ >>. Only a fixed set of files may be
fetched:

    reports/lite.json
    reports/report.json
    reports/report.html
    reports/summary-report.html
    shots/*.jpg

Access is gated by L<CAPE::Utils/check_remote_results>, which uses the separate
C<results_auth>, C<results_apikey>, and C<results_subnets> config so results can
be locked down independently of submission.

=head2 results_list

List which of the fetchable result files exist for a task. Returns a response
hashref whose C<body> is a JSON array of the available relative paths.

    my $result = $submitter->results_list(
        task_id   => 33,
        remote_ip => $c->tx->original_remote_address,
        apikey    => $c->param('apikey'),
    );
    $c->render( text => $result->{body}, status => $result->{status} );

Arguments are taken as a hash.

    - task_id :: The CAPEv2 task ID.

    - remote_ip :: The remote IP of the requester.

    - apikey :: The submitted API key, or undef.

=cut

sub results_list {
	my ( $self, %opts ) = @_;

	my ( $cape_util, $auth_err ) = $self->_results_auth(%opts);
	return $auth_err if ($auth_err);

	my $task_id = $opts{task_id};
	if ( !defined($task_id) || $task_id !~ /^[0-9]+$/ ) {
		return { status => 400, body => "Invalid task ID\n" };
	}

	my $task_dir = $cape_util->get_analyses_dir . '/' . $task_id;
	if ( !-d $task_dir ) {
		return { status => 404, body => "No such task\n" };
	}

	my @available;
	foreach my $candidate ( _results_candidates() ) {
		if ( -f $task_dir . '/' . $candidate ) {
			push( @available, $candidate );
		}
	}

	# shots are a dynamic set of jpgs, so enumerate whatever is present
	my $shots_dir = $task_dir . '/shots';
	my $dh;
	if ( -d $shots_dir && opendir( $dh, $shots_dir ) ) {
		my @shots = sort grep { /^[A-Za-z0-9_\-]+\.jpg$/ && -f $shots_dir . '/' . $_ } readdir($dh);
		closedir($dh);
		foreach my $shot (@shots) {
			push( @available, 'shots/' . $shot );
		}
	}

	return { status => 200, body => encode_json( \@available ) . "\n" };
} ## end sub results_list

=head2 results_fetch

Validate and locate a single result file for a task. On success returns a
response hashref with C<path> (the absolute file path) and C<content_type> set,
which the front end serves directly. On failure C<status> and C<body> are set
instead.

    my $result = $submitter->results_fetch(
        task_id   => 33,
        path      => 'reports/lite.json',
        remote_ip => $c->tx->original_remote_address,
        apikey    => $c->param('apikey'),
    );
    if ( $result->{path} ) {
        $c->res->headers->content_type( $result->{content_type} );
        $c->reply->file( $result->{path} );
    } else {
        $c->render( text => $result->{body}, status => $result->{status} );
    }

Only the files reported by L</results_list> may be fetched. Any path outside the
allowed set, including traversal attempts, yields a 404.

=cut

sub results_fetch {
	my ( $self, %opts ) = @_;

	my ( $cape_util, $auth_err ) = $self->_results_auth(%opts);
	return $auth_err if ($auth_err);

	my $task_id = $opts{task_id};
	if ( !defined($task_id) || $task_id !~ /^[0-9]+$/ ) {
		return { status => 400, body => "Invalid task ID\n" };
	}

	my $path = $opts{path};
	if ( !_results_path_allowed($path) ) {
		return { status => 404, body => "Not found\n" };
	}

	my $task_dir = $cape_util->get_analyses_dir . '/' . $task_id;
	my $file     = $task_dir . '/' . $path;

	# belt and suspenders against traversal: the resolved path must exist and
	# still live under the task dir. The allowlist above already blocks '..',
	# but this catches anything symlinks or odd input might sneak through.
	my $abs_task = abs_path($task_dir);
	my $abs_file = abs_path($file);
	if (   !defined($abs_task)
		|| !defined($abs_file)
		|| !-f $abs_file
		|| index( $abs_file, $abs_task . '/' ) != 0 )
	{
		return { status => 404, body => "Not found\n" };
	}

	return {
		status       => 200,
		path         => $abs_file,
		content_type => _results_content_type($path),
	};
} ## end sub results_fetch

# Build a CAPE::Utils and run the results ACL. Returns ($cape_util, undef) on
# success or (undef, $response) on failure so callers can early return.
sub _results_auth {
	my ( $self, %opts ) = @_;

	my $cape_util;
	eval { $cape_util = CAPE::Utils->new( $self->{ini} ); };
	if ($@) {
		_log_drek( 'err', $@ );
		return ( undef, { status => 400, body => "Error... please see syslog\n" } );
	}

	my $allow;
	eval { $allow = $cape_util->check_remote_results( apikey => $opts{apikey}, ip => $opts{remote_ip} ); };
	if ($@) {
		_log_drek( 'err', $@ );
		return ( undef, { status => 400, body => "Error... please see syslog\n" } );
	}
	if ( !$allow ) {
		_log_drek( 'info', 'results: API key or IP not allowed' );
		return ( undef, { status => 403, body => "IP not allowed or invalid API key\n" } );
	}

	return ( $cape_util, undef );
} ## end sub _results_auth

# the fixed candidate result files, relative to the task dir; shots are dynamic
sub _results_candidates {
	return ( 'reports/lite.json', 'reports/report.json', 'reports/report.html', 'reports/summary-report.html' );
}

# true if $path is a fetchable result: one of the fixed candidates or a shot jpg
sub _results_path_allowed {
	my ($path) = @_;

	return 0 if ( !defined($path) );
	foreach my $candidate ( _results_candidates() ) {
		return 1 if ( $path eq $candidate );
	}
	return 1 if ( $path =~ m,^shots/[A-Za-z0-9_\-]+\.jpg$, );
	return 0;
} ## end sub _results_path_allowed

# content type for a fetchable result path, based on its extension
sub _results_content_type {
	my ($path) = @_;

	return 'application/json' if ( $path =~ /[.]json$/ );
	return 'text/html'        if ( $path =~ /[.]html$/ );
	return 'image/jpeg'       if ( $path =~ /[.]jpg$/ );
	return 'application/octet-stream';
}

=head1 AUTHOR

Zane C. Bowers-Hadley, C<< <vvelox at vvelox.net> >>

=cut

1;
