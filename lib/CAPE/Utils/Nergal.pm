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
use IPC::Cmd             qw( run_forked );
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

=head1 SUBMISSION GATE

The 'submission_gate' config value is a command ran per submission to decide what
becomes of it. It is empty by default, which disables it entirely. What it does
is taken from how it exits.

    0 -- Accept it. Saved and submitted as normal.

    1 -- Accept and save it, but do not submit it.

    2 -- Accept it, but neither save nor submit it. Nothing is kept.

    3 -- Deny it, temporarily. Replied to with a 444.

    4 -- Deny it, permanently. Replied to with a 445.

    5 -- Deny it, generically, for anything else. Replied to with a 403.

Exits 0 and 1 are replied to with the usual task ID and an "Accepted"
respectively, and 2 with an "Accepted" as well, it having been accepted but
simply not kept.

Anything else is a gate that is broken rather than one making a call on the
submission, and is handled like any other nergal error, meaning the submission is
dropped and replied to with a 400. A gate that could not be ran, timed out, or
was killed is treated the same way. So a broken gate never quietly accepts or
denies anything, but it does mean a bad 'submission_gate' stops submissions until
it is fixed.

The gate is ran after the submission has been authed and checksummed but before
anything is written out of tmp, which is what lets an exit of 2 leave nothing
behind. Ping tests are replied to before any of this and never reach the gate.

It is ran via '/bin/sh -c', so it may be a pipeline or hold redirects, and its
stdout, stderr, and exit are all logged. Where the submission is saved, exits 0
and 1, what it had to say is also recorded in the incoming JSON as
'.cape_submit.gate_results'.

How long it is given to run is set via 'submission_gate_timeout', which defaults
to 30 seconds.

=head2 GATE ENVIROMENTAL VARIABLES

The submission is described to the gate through the enviroment. Anything not
known is left unset rather than set to nothing, so a gate can tell a value that
is missing from one that is genuinely blank.

    NERGAL_FILE      -- Path to the submitted file, which is still in tmp.

    NERGAL_FILENAME  -- The submitted file name, with any directory bits stripped
                        off of it, as it will be saved under in incoming.

    NERGAL_JSON      -- Path to the JSON as submitted. Only set where a body was
                        submitted and it decoded to a hash. Removed once the gate
                        has ran.

    NERGAL_SLUG      -- The submitter's slug.

    NERGAL_MIME      -- The mime type, with any '/' replaced by '_'.

    NERGAL_SHA256    -- Checksums of the file as received.
    NERGAL_SHA1
    NERGAL_MD5

    NERGAL_SRC_IP    -- The flow the file was extracted from.
    NERGAL_SRC_PORT
    NERGAL_DEST_IP
    NERGAL_DEST_PORT
    NERGAL_PROTO     -- 'TCP' or 'UDP'.
    NERGAL_APP_PROTO -- 'http', 'tls', 'smb', and the like.

The slug, mime, and flow info are all as of after anything recoverable from the
submitted filename has been filled in, so a tool submitting in the standard name
format without a JSON body is still described to the gate in full. See
L</parse_name>.

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

# How the submission gate exiting maps to what is done with the submission.
#   save   -- keep the sample and write the incoming JSON out
#   submit -- hand it off to CAPE
#   reply  -- what the submitter is told where there is no task ID to report
# Anything not in here is a gate that is broken rather than one making a call,
# and is handled like any other nergal error, as is a gate that timed out, was
# killed, or could not be ran at all.
our %GATE_ACTIONS = (
	0 => { save => 1, submit => 1 },
	1 => { save => 1, submit => 0, reply => { status => 200, body => "Accepted\n" } },
	2 => { save => 0, submit => 0, reply => { status => 200, body => "Accepted\n" } },
	3 => { save => 0, submit => 0, reply => { status => 444, body => "Denied\n" } },
	4 => { save => 0, submit => 0, reply => { status => 445, body => "Denied\n" } },
	5 => { save => 0, submit => 0, reply => { status => 403, body => "Denied\n" } },
);

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

The C<json> body is optional. Where none was submitted, or what was submitted
did not decode to a hash, the submitted name is fallen back on. When it parses
via L</parse_name>, the submission is treated as a standard
suricata_extract_submit one and the fields recoverable from the name are filled
in before the JSON is written out: C<< .src_ip >>, C<< .src_port >>,
C<< .dest_ip >>, C<< .dest_port >>, and C<< .proto >> at the top level, plus
C<< .suricata_extract_submit >>'s C<filename>, C<slug>, C<md5>, C<time>,
C<timestamp>, and C<mime>. Nothing is filled in unless the name parses in full.

The digest in the name is recorded as the C<md5>, as the tools submitting
without a body put the first 18 characters of the md5 there. L</parse_name>
returns it as the C<sha1>, that being what current suricata_extract_submit puts
in the name, and nothing in the name marks which of the two it is.

A submitter that sent a usable body is taken at its word and nothing is padded
from the name, even where the body left fields out. So a submitter wanting the
name fallen back on for the bits it does not have should send no body at all
rather than a partial one.

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
	# the body as submitted, only set when one was actually sent and usable, as
	# that is what decides if the submission gate is handed a NERGAL_JSON
	my $submitted_json;
	eval { $json = decode_json($raw_json); };
	if ($@) {
		_log_drek( 'err', 'json param decode error: ' . $@ );
		$json = {};
	} elsif ( ref($json) eq 'HASH' ) {
		$submitted_json = $raw_json;
	}

	# a JSON body is optional and some submitters send none... a top level that is
	# not a hash would blow up everything below, so treat it as nothing submitted
	if ( ref($json) ne 'HASH' ) {
		_log_drek( 'err', 'json param did not decode to a hash... ignoring it', $tracking );
		$json = {};
	}

	# Tools other than suricata_extract_submit submit using the same name format
	# but without the JSON body that normally carries the flow info and the slug.
	# Only where nothing usable was submitted is the name fallen back on, as a
	# submitter that sent a body is taken at its word about what the submission is.
	# When the name parses in full, treat it as a standard suricata_extract_submit
	# submission and fill in what the name gives us. A name that does not fully
	# parse pads nothing at all. $json is an empty hash at this point, given
	# nothing was submitted, so there is nothing here to be written over.
	if ( !defined($submitted_json) ) {
		my $from_name = $self->parse_name($name);
		if ( defined($from_name) ) {
			foreach my $field (qw( src_ip src_port dest_ip dest_port proto )) {
				$json->{$field} = $from_name->{$field};
			}

			# The sha256, host, to, and apikey the section normally holds are not
			# recoverable from the name, so only what is in it is filled in. The
			# digest goes in as the md5, as that is what the tools submitting
			# without a body put in the name, the first 18 characters of it. It is
			# L</parse_name>'s sha1 as that is what current suricata_extract_submit
			# puts there instead, with nothing in the name marking which it is.
			my $from_name_section = {
				filename  => $name,
				slug      => $from_name->{slug},
				md5       => $from_name->{sha1},
				time      => $from_name->{time},
				timestamp => $from_name->{timestamp},
				mime      => $from_name->{mime},
			};
			$json->{suricata_extract_submit} = $from_name_section;

			# log the name it was all read out of along with every value set from
			# it, so what a submission was taken as is recoverable from the log
			my $padded_message = 'Padded submission from name "' . $name . '"...';
			foreach my $field (qw( src_ip src_port dest_ip dest_port proto )) {
				$padded_message = $padded_message . ' .' . $field . '="' . $json->{$field} . '"';
			}
			foreach my $field ( sort( keys( %{$from_name_section} ) ) ) {
				$padded_message
					= $padded_message
					. ' .suricata_extract_submit.'
					. $field . '="'
					. $from_name_section->{$field} . '"';
			}
			_log_drek( 'info', $padded_message, $tracking );
		} ## end if ( defined($from_name) )
	} ## end if ( !defined($submitted_json) )

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

	# The sub sections the gate below and the logging further down pull values out
	# of. Each is only taken as a ref when it is actually there, as dereferencing
	# $json->{http} and friends directly would autovivify them, leaving an empty
	# section in the JSON that gets written out.
	my $http = ref( $json->{'http'} ) eq 'HASH' ? $json->{'http'} : {};
	my $suricata_section
		= ref( $json->{'suricata_extract_submit'} ) eq 'HASH' ? $json->{'suricata_extract_submit'} : {};
	my $lilith_section = ref( $json->{'lilith_cape_submit'} ) eq 'HASH' ? $json->{'lilith_cape_submit'} : {};

	# Hand it off to the submission gate, if one is configured, and take what to
	# do with the submission from how the gate exited. This sits ahead of the save
	# below so a gate can have a submission dropped without a trace of it being
	# left behind, which means the sample is still sitting in tmp/ at this point.
	my $save   = 1;
	my $submit = 1;
	my $gate;
	my $gate_reply;
	my $gate_command = $cape_util->{config}->{_}->{submission_gate};
	if ( defined($gate_command) && $gate_command ne '' ) {
		eval {
			$gate = $self->_submission_gate(
				command        => $gate_command,
				timeout        => $cape_util->{config}->{_}->{submission_gate_timeout},
				tracking       => $tracking,
				submitted_json => $submitted_json,
				env            => {
					NERGAL_FILE      => $temp_filename,
					NERGAL_FILENAME  => $name,
					NERGAL_SLUG      => $suricata_section->{'slug'},
					NERGAL_MIME      => $suricata_section->{'mime'},
					NERGAL_SHA256    => $checksums->{sha256},
					NERGAL_SHA1      => $checksums->{sha1},
					NERGAL_MD5       => $checksums->{md5},
					NERGAL_SRC_IP    => $json->{'src_ip'},
					NERGAL_SRC_PORT  => $json->{'src_port'},
					NERGAL_DEST_IP   => $json->{'dest_ip'},
					NERGAL_DEST_PORT => $json->{'dest_port'},
					NERGAL_PROTO     => $json->{'proto'},
					NERGAL_APP_PROTO => $json->{'app_proto'},
				},
			);
		};
		if ($@) {
			_log_drek( 'err', 'submission_gate: ' . $@, $tracking );
			unlink($temp_filename);
			return { status => 400, body => "Error... please see syslog\n" };
		}

		# an exit not in the table means the gate is broken rather than making a
		# call on the submission, so it is treated like any other nergal error
		my $action = $GATE_ACTIONS{ defined( $gate->{exit_code} ) ? $gate->{exit_code} : 'undef' };
		if ( !defined($action) ) {
			unlink($temp_filename);
			return { status => 400, body => "Error... please see syslog\n" };
		}

		$save       = $action->{save};
		$submit     = $action->{submit};
		$gate_reply = $action->{reply};
	} ## end if ( defined($gate_command) && $gate_command...)

	# nothing is kept for a submission the gate declined to have saved, so there
	# is nothing to do past dropping the sample and telling the submitter
	if ( !$save ) {
		unlink($temp_filename);
		return $gate_reply;
	}

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
	# $http, $suricata_section, and $lilith_section are all taken further up, ahead
	# of the submission gate, which needs values out of them as well
	$additional_info{http_host}    = $http->{'hostname'};
	$additional_info{http_url}     = $http->{'url'};
	$additional_info{http_method}  = $http->{'method'};
	$additional_info{http_proto}   = $http->{'protocol'};
	$additional_info{http_status}  = $http->{'status'};
	$additional_info{http_ctype}   = $http->{'http_content_type'};
	$additional_info{http_ua}      = $http->{'http_user_agent'};
	$additional_info{det_sub_type} = $http->{'http_method'};

	$additional_info{src_host} = $suricata_section->{'host'} // $lilith_section->{'host'};

	# record the submission type before the loop below, as that turns undefs into
	# the string 'undef' for logging purposes and a submission with no http method
	# should not have a literal "undef" written out into its JSON... anything the
	# submitter put there is left alone where there is no method to override it
	if ( defined( $additional_info{det_sub_type} ) ) {
		$json->{det_sub_type} = $additional_info{det_sub_type};
	}

	# set the value for anything not defined to undef for the purpose of logging
	# this will avoid perl from throwing errors about undef used in cating
	foreach my $item ( keys(%additional_info) ) {
		if ( !defined( $additional_info{$item} ) ) {
			$additional_info{$item} = 'undef';
		}
	}

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

	# finally submit it, unless the gate said to save it without submitting, in
	# which case its reply is what the submitter gets as there is no task to name
	my $response = $gate_reply;
	my $task_value;
	if ($submit) {
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
		$task_value = $results->{ $submitted[0] };
		my @task_ids   = split( /,/, $task_value );
		my $id_wording = defined( $task_ids[1] ) ? 'task IDs' : 'task ID';
		_log_drek( 'info', 'Submitting "' . $name . '" submitted as ' . $task_value, $tracking );
		$response = { status => 200, body => 'Submitted as ' . $id_wording . ' ' . $task_value . "\n" };
		$json->{cape_submit}{task} = $task_value;
	} else {
		_log_drek( 'info', 'Not submitting "' . $name . '" as the submission gate said not to', $tracking );
	}

	# record what the gate had to say about it, for anything going over the
	# incoming JSONs later
	if ($gate) {
		$json->{cape_submit}{gate_results} = {
			exit   => $gate->{exit_code},
			stdout => $gate->{stdout},
			stderr => $gate->{stderr},
		};
	}

	# write out the json containing the submission info
	eval { $self->_write_json( $json_filename, $json ); };
	if ($@) {
		_log_drek( 'err', 'Failed to write submission data JSON out to "' . $json_filename . '"... ' . $@ );
	} else {
		_log_drek( 'info', 'Wrote submission data JSON out to "' . $json_filename . '"', $tracking );
		# nothing to link it to where it was saved without being submitted
		if ( defined($task_value) ) {
			eval { $self->_link_task_to_json( $task_value, $json_filename ); };
			if ($@) {
				_log_drek( 'err', $@, $tracking );
			}
		}
	} ## end else [ if ($@) ]

	return $response;
} ## end sub receive

# Run the configured submission gate and return what it had to say as a hash ref
# of exit_code, stdout, and stderr. exit_code is undef where the gate did not run
# to completion, which the caller treats the same as an exit it does not know.
# Takes command, timeout, tracking, submitted_json, and env, the last being the
# NERGAL_ prefixed vars the gate is told about the submission through.
sub _submission_gate {
	my ( $self, %opts ) = @_;

	my $timeout = $opts{timeout};
	if ( !defined($timeout) || $timeout !~ /^\d+$/ ) {
		$timeout = 30;
	}

	# anything not defined is left unset rather than set empty, so a gate can tell
	# a value that is missing from one that is genuinely blank
	my %env;
	foreach my $var ( keys( %{ $opts{env} } ) ) {
		if ( defined( $opts{env}{$var} ) ) {
			$env{$var} = $opts{env}{$var};
		}
	}

	# The JSON is handed over as a file the same way the sample is, as a big
	# enough env var makes the exec fail outright, and the json param has no size
	# limit of its own past the max request size.
	my $json_file;
	if ( defined( $opts{submitted_json} ) ) {
		my $json_fh;
		( $json_fh, $json_file ) = tempfile( 'DIR' => $self->{incoming} . '/tmp' );
		print {$json_fh} $opts{submitted_json};
		close($json_fh);
		$env{NERGAL_JSON} = $json_file;
	}

	# Ran through a shell explicitly rather than handed over as is. IPC::Cmd only
	# uses a shell when the command holds something needing one, and a gate that
	# does not exist then comes back as having exited 2, which is a meaningful
	# value here. Going through a shell every time makes that a 127 instead, and
	# means a gate can be a pipeline or hold redirects regardless. Passing it as a
	# string is deliberate as well, as IPC::Cmd 1.04 eats the first line of stdout
	# when handed a command as an array ref.
	my $to_run = $opts{command};
	$to_run =~ s/'/'\\''/g;
	$to_run = "/bin/sh -c '" . $to_run . "'";

	_log_drek( 'info', 'submission_gate: running "' . $opts{command} . '"', $opts{tracking} );

	my $results;
	{
		# scoped so the vars do not leak into anything ran later on
		local %ENV = ( %ENV, %env );
		$results = run_forked( $to_run, { timeout => $timeout } );
	}

	if ( defined($json_file) ) {
		unlink($json_file);
	}

	foreach my $stream (qw( stdout stderr )) {
		if ( defined( $results->{$stream} ) ) {
			foreach my $line ( split( /\n/, $results->{$stream} ) ) {
				_log_drek( 'info', 'submission_gate ' . $stream . ': ' . $line, $opts{tracking} );
			}
		}
	}

	# a gate that timed out or was killed comes back as having exited 0, which
	# would otherwise be taken as it having accepted the submission
	if ( $results->{timeout} ) {
		_log_drek( 'err', 'submission_gate: timed out after ' . $timeout . ' seconds', $opts{tracking} );
		return { exit_code => undef, stdout => $results->{stdout}, stderr => $results->{stderr}, };
	} elsif ( $results->{killed_by_signal} ) {
		_log_drek( 'err', 'submission_gate: killed by signal ' . $results->{killed_by_signal}, $opts{tracking} );
		return { exit_code => undef, stdout => $results->{stdout}, stderr => $results->{stderr}, };
	}

	my $exit_code = $results->{exit_code};
	my $level     = defined( $GATE_ACTIONS{$exit_code} ) ? 'info' : 'err';
	_log_drek( $level, 'submission_gate: exited ' . $exit_code, $opts{tracking} );

	return { exit_code => $exit_code, stdout => $results->{stdout}, stderr => $results->{stderr}, };
} ## end sub _submission_gate

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
