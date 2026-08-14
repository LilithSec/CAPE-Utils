# CAPE-Utils

Utilities for use with CAPEv2.

Six scripts are installed.

- `cape_utils` :: The CLI for everything local to the CAPE box. Submitting,
  listing and failing tasks, processing the EVE log, and the post detonation
  actions all live here. See [cape_utils](#cape_utils) below.

- `nergal` :: A daemon accepting remote submissions over HTTP and handing them
  to CAPE, and serving the results back. Formerly `mojo_cape_submit`.

- `mojo_cape_submit` :: A wrapper that execs `nergal`, so anything still calling
  it by the old name keeps working. New setups should call `nergal` directly.

- `suricata_extract_submit` :: Ran from cron on a Suricata sensor, submitting
  the files Suricata extracts to `nergal`. This is the one piece meant to run
  somewhere other than the CAPE box.

- `suricata_extract_submit_extend` and `nergal_extend` :: SNMP extends
  reporting stats for the two above. See [SNMP Extends](#snmp-extends) below.

## Installation

### From Source

```
perl Makefile.PL
make
make test
make install
```

### FreeBSD

Only relevant for `suricata_extract_submit`.

```
pkg install p5-App-cpanminus
cpanm CAPE::Utils
```

### Debian/Ubuntu

For Debian, only `suricata_extract_submit` is relevant.

```
apt-get install cpanminus
cpanm CAPE::Utils
```

## cape_utils

`cape_utils` is an [App::Cmd](https://metacpan.org/pod/App::Cmd) application,
so each action is its own sub command.

```
cape_utils commands            # list them
cape_utils help <command>      # the options for one of them
cape_utils version
```

### General Flags

- `-i <ini>` :: The config INI file. Defaults to
  '/usr/local/etc/cape_utils.ini'.

- `--json` :: Output the result as JSON rather than a table.

- `--pretty` :: Pretty print that JSON.

### Commands

- `submit` :: Submit files or dirs to CAPE. `--mime-package` works the package
  out per item from its mime type, and `--dry-run` prints what would be
  submitted without submitting it.

- `resub` :: Resubmit a sample originally submitted via `nergal`, found by
  either its incoming name (`-n`) or a task ID (`-r`).

- `running`, `pending`, `tasks` :: Show tasks in those states. `-C` prints just
  the count and `-w` takes a SQL where fragment to narrow it down.

- `fail` :: Fail pending tasks matching `-w`.

- `eve` :: Process finished tasks into the EVE log. See
  [cape_utils eve](#cape_utils-eve) below for running it on a timer.

- `munge` :: Munge a report JSON.

- `post` :: Run the configured post detonation actions for a run ID. `-d`
  describes what would be done instead of doing it.

- `exec` :: Run a command from the CAPE base dir, wrapped in "poetry run" when
  poetry is enabled. Everything after `--` is the command.

- `poetry` :: Run a poetry command from the CAPE base dir. Unlike `exec`,
  everything after `--` goes straight to poetry.

- `mime_to_packages` :: Show the mime type to package settings.

`submit`, `exec`, and `poetry` have to run as the configured `cape_runas` user.
When they are not, they prepend "sudo -u \<cape_runas\>" if `enable_sudo` is
set, and die otherwise. `submit --dry-run` is the exception and may be run by
anyone, as it submits nothing.

### Legacy Command Line

The pre-App::Cmd command line still works. Invocations using the old
`cape_utils -a <action>` form, with `-c`/`--config` for the INI file, are
rewritten into the sub command form, so these are equivalent.

```
cape_utils -a submit -c /etc/cape_utils.ini foo
cape_utils submit -i /etc/cape_utils.ini foo
```

## Configuration

### suricata_extract_submit

The config file used is '/usr/local/etc/suricata_extract_submit.ini'.

```
# the API key to use if needed
#apikey=

# URL to find nergal at
url=http://192.168.14.15:8080/

# the group/client/whathaveya slug
slug=foo

# where Suricata has the file store at
filestore=/var/log/suricata/files

# a file of IPs or subnets to ignore SRC or DEST IPs of
#ignore=

# a file of regex to use for checking host names to ignore
#ignoreHosts=

# a file of regex to use for checking user agents to ignore
#ignoreUA=

# a file of regex to use for checking path chunks of the URL to ignore
#ignorePaths=

# the largest a extracted file may be, in bytes, before it is ignored
ignoreMaxSize=52428800

# a JSON file to use for using with Web::ACL for checking for ignores
#ignoreWebACL=/usr/local/etc/suricata_extract_submit_webacl.json

# if it should use HTTPS_PROXY and HTTP_PROXY from ENV or not
env_proxy=0

# stats file holding only the stats for the last run
stats_file=/var/cache/suricata_extract_submit_stats.json

# stats dir
stats_dir=/var/cache/suricata_extract_submit_stats/
```

Then a cron job set up like below.

```
*/5 * * * * /usr/local/bin/suricata_extract_submit 2> /dev/null > /dev/null
```

Suricata just needs the file-store output setup akin to below.

```
  - file-store:
      version: 2
      enabled: yes
      dir: /var/log/suricata/files
      write-fileinfo: yes
      stream-depth: 0
      force-hash: [sha1, md5]
      xff:
        enabled: no
        mode: extra-data
        deployment: reverse
        header: X-Forwarded-For
```

### CAPE::Utils

The default config file is '/usr/local/etc/cape_utils.ini'.

The defaults are as below, which out of the box will work with CAPEv2
in its default config.

```
# The DBI dsn to use
dsn=dbi:Pg:dbname=cape
# DB user
user=cape
# DB password
pass=
# the install base for CAPEv2
base=/opt/CAPEv2/
# 0/1 if poetry should be used
poetry=1
# the path for poetry... point this at where poetry is setup for your CAPEv2 install
# defaults to /etc/poetry/bin/poetry to be compatible with new CAPEv2 installs
poetry_path=/etc/poetry/bin/poetry
# the user that submit/exec must be ran as
cape_runas=cape
# 0/1 if, when not already running as cape_runas, submit/exec should
# prepend "sudo -u <cape_runas>" to change users instead of dying
# defaults to 1 when ran as root, otherwise 0
enable_sudo=1
# 0/1 if fail should be allowed to run with out a where statement
fail_all=0
# columns to use for pending table show
pending_columns=id,target,package,timeout,ET,route,options,clock,added_on
# columns to use for running table show
running_columns=id,target,package,timeout,ET,route,options,clock,added_on,started_on,machine
# columns to use for tasks table
task_columns=id,target,package,timeout,ET,route,options,clock,added_on,latest,machine,status
# if the target column for running table display should be clipped to the filename
running_target_clip=1
# if microseconds should be clipped from time for running table display
running_time_clip=1
# if the target column for pending table display should be clipped to the filename
pending_target_clip=1
# if microseconds should be clipped from time for pending table display
pending_time_clip=1
# if the target column for task table display should be clipped to the filename
task_target_clip=1
# if microseconds should be clipped from time for task table display
task_time_clip=1
# default table color
table_color=Text::ANSITable::Standard::NoGradation
# default table border
table_border=ASCII::None
# when submitting use now for the current time
set_clock_to_now=1
# default timeout value for submit
timeout=200
# default value for enforce timeout for submit
enforce_timeout=0
# how to auth for nergal
# ip = match against subnets
# apikey = use apikey
# both = require both to match
# either = either may work
auth=ip
# the api key to for with nergal
#apikey=
# comma separated list of allowed subnets for nergal
subnets=192.168.0.0/16,127.0.0.1/8,::1/128,172.16.0.0/12,10.0.0.0/8
# how to auth for the nergal results endpoint (ip/apikey/both/either), like auth above
results_auth=ip
# the api key for the nergal results endpoint
#results_apikey=
# comma separated list of allowed subnets for the nergal results endpoint
results_subnets=192.168.0.0/16,127.0.0.1/8,::1/128,172.16.0.0/12,10.0.0.0/8
# incoming dir to use for nergal
incoming=/malware/client-incoming
# a command ran per nergal submission to decide what becomes of it, via how it
# exits... empty, the default, disables it
# see the SUBMISSION GATE section of CAPE::Utils::Nergal for what the exits mean
#submission_gate=
# how many seconds the submission gate is given before it is killed
submission_gate_timeout=30
# Location to write the eve log to.
eve=/opt/CAPEv2/log/eve.json
# how far to go back for processing eve
eve_look_back=360
# malscore for changing the event_type for eve from potential_malware_detonation to alert
malscore=0
# If munge should be called on the report JSON for the post action.
post_munge=0
# If the binary should be removed during the post action.
post_bin_rm=0
# If symbolic links should be created for the report dir during the post action.
post_link=0
# Where to create the symbolic links to the submissions report dir
post_link_dir=/malware/storage/links
# The Template Toolkit template the post action link names are rendered from,
# with the parsed report available as the 'lite' variable
post_link_format_template=[% lite.target.file.name %]
# A file to read post_link_format_template from, which wins over the setting
# above when it exists, so a multi line template does not have to fit on a
# single INI line
post_link_format_template_file=/usr/local/etc/cape_utils_link_format_template.t2
# 0/1 if submit should work the package out per item from its mime type
mime_to_package=0
# the package to use for mime types with no mapping in the mime_packages section
# set to 'auto' or leave empty to submit those with no package, letting CAPE decide
mime_to_package_default=exe
# 0/1 if items resolving to the exe package should be checked for being a DLL
# libmagic uses the same mime type for both, so the description is all there is to go on
dll_check=1

# maps mime types to the CAPE package to submit them with, only used when
# mime_to_package is enabled... these are merged in per key, so listing a
# few here does not remove the shipped defaults
[mime_packages]
application/pdf=pdf
application/x-msi=msi
# 'auto' means submit with no package, letting CAPE decide
application/x-ole-storage=auto
# a empty value unsets a shipped mapping, falling through to mime_to_package_default
text/plain=
```

Mime types are detected via File::LibMagic. A package passed to `cape_utils
submit --package` always wins over this, with `--package auto` meaning submit
with no package at all.

`cape_utils submit --dry-run` prints the mime type and package worked out for
each item without submitting anything, and may be ran as any user.

`cape_utils mime_to_packages` prints the current settings and mappings.
`--as-ini` prints them as INI and `--diff` limits it to what differs from the
shipped defaults, so `--as-ini --diff` is a minimal config fragment.

### nergal

If cape_utils has been configured and is working, this just requires
the 'incoming' setting configured.

The 'incoming' setting is a directory in which incoming files are placed
for submission. By default this is '/malware/client-incoming'. The
submission data JSON, checksum store, and task-to-JSON links are all kept
in subdirectories beneath it. See the "INCOMING DIR STRUCTURE" section of
`perldoc CAPE::Utils::Nergal` for the layout.

That directory has to exist and be writable by the user nergal runs as. The
subdirectories under it do not, as nergal creates any that are missing when it
starts. The incoming directory itself is deliberately never created, since it is
usually a mount and creating it would turn a failed mount into samples landing on
the wrong filesystem. If it is missing, nergal still starts, logs why, and
refuses submissions until it appears.

```
mkdir -p /malware/client-incoming
chown cape:cape /malware/client-incoming
```

By default this will auth of the remote IP via the setting 'subnets',
which by default is
'192.168.0.0/16,127.0.0.1/8,::1/128,172.16.0.0/12,10.0.0.0/8'. This
value is a comma seperated string of subnets to accept submissions
from.

To enable the use of a API key, set the value of 'apikey' and set 'auth'
to 'apikey' (key only), 'both' (key and IP), or 'either' (key or IP).

Submissions are POST only, and the path is not matched on at all, so '/',
'/submit', or a CGI one like '/cgi-bin/whatever.cgi' all work. Opening a
submission URL in a browser is a GET, which nergal answers with a 405 and an
'Allow: POST' rather than accepting anything. To check a submission path end to
end, POST the ten byte ping, which is answered with "TEST RECIEVED" and is not
saved or detonated.

```
printf 1234567890 > /tmp/nergal-ping
curl -F filename=@/tmp/nergal-ping https://cape.example.net:8443/cgi-bin/whatever.cgi
```

GET is only used for the results endpoint below.

The provided systemd service file runs nergal under hypnotoad, Mojolicious'
preforking server, so submissions are handled by a pool of workers rather than
one process at a time. Using it, you will also need to create
'/usr/local/etc/nergal.env' and configure it akin to below.

```
LISTEN_ON="http://192.168.14.15:8080"
```

More than one may be listened on, seperated by whitespace.

```
LISTEN_ON="http://192.168.14.15:8080 http://127.0.0.1:8080"
```

For TLS, make it a 'https://' listen and point 'cert' and 'key' at the
certificate and its key via the query string.

```
LISTEN_ON="https://192.168.14.15:8443?cert=/usr/local/etc/nergal/cert.pem&key=/usr/local/etc/nergal/key.pem"
```

The '&' needs no escaping, as systemd runs 'ExecStart' directly rather than
through a shell. Both files have to be readable by the user nergal runs as,
'cape' by default.

```
install -d -o cape -g cape -m 0750 /usr/local/etc/nergal
install -o cape -g cape -m 0444 fullchain.pem /usr/local/etc/nergal/cert.pem
install -o cape -g cape -m 0400 privkey.pem /usr/local/etc/nergal/key.pem
systemctl restart nergal
```

'cert' should be the full chain where a intermediate is involved, as nothing
else is sent to the client. A 'https://' listen without 'cert' and 'key' still
comes up, but on Mojolicious' built in test certificate, which is self signed,
issued to 'localhost', and shipped with its private key, so always set them.
Renewing means restarting nergal, as the certificate is read at listen time.

```
LISTEN_ON="https://192.168.14.15:8443?cert=/usr/local/etc/nergal/cert.pem&key=/usr/local/etc/nergal/key.pem&ca=/usr/local/etc/nergal/ca.pem"
```

The rest of what may be set, such as 'ciphers' and 'version', is covered in
`perldoc Mojo::Server::Daemon` under 'listen'.

Hypnotoad takes its settings from the application rather than the command line,
so nergal hands it these from the environment. The other two are optional.

```
# how many worker processes to run, hypnotoad's own default being 4. A worker is
# tied up for as long as handing the sample to CAPE takes, so this is how many
# submissions may be handled at once.
NERGAL_WORKERS="8"
# where hypnotoad keeps its pid file. The unit sets this to /run/nergal/nergal.pid,
# a runtime dir it has systemd create as the user nergal runs as, so this only
# needs setting when running hypnotoad by hand, as its own default is a
# 'hypnotoad.pid' next to the nergal script.
NERGAL_PID_FILE="/run/nergal/nergal.pid"
```

Deploy with a plain `systemctl restart nergal`. Hypnotoad's hot deployment,
running it a second time or sending it a USR2, replaces the manager process
with a new one, which systemd sees as the service having died, so do not use it
under the unit.

With more than one worker, the tracking int in the log is per worker rather than
global, so pair it with the pid syslog records when following a submission
through the log.

The service runs as the user and group 'cape' via the unit's 'User='
and 'Group=' directives. If you need it to run as a different user, edit
those in 'systemd/nergal.service' rather than setting an environment
variable.

If Mojolicious came from your distribution rather than CPAN, hypnotoad is
generally '/usr/bin/hypnotoad' rather than the '/usr/local/bin/hypnotoad' the
unit's 'ExecStart=' uses, so adjust that as needed.

### nergal results endpoint

nergal can also serve the detonation results CAPEv2 writes under
'<base>/storage/analyses/<task_id>/' via GET.

```
# JSON array of which result files exist for a task
GET /results/<task_id>
# fetch one of them
GET /results/<task_id>/<path>
```

Only a fixed set of files may be fetched: 'reports/lite.json',
'reports/report.json', 'reports/report.html',
'reports/summary-report.html', and 'shots/*.jpg'. Anything else,
including path traversal attempts, returns a 404.

Access is gated separately from submission via the 'results_auth',
'results_apikey', and 'results_subnets' config values, so results can be
locked down independently. If an API key is used it is passed as the
'apikey' query parameter.

### cape_utils eve

`cape_utils eve` is not a daemon. It is meant to be run periodically to
process CAPE's eve.json output. Provided systemd unit files handle this
via a timer that runs it every two minutes as the user `cape`.

```
cp systemd/cape_utils_eve.service systemd/cape_utils_eve.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now cape_utils_eve.timer
```

Only the timer is enabled. It triggers `cape_utils_eve.service`, which
runs `/usr/local/bin/cape_utils eve`. The next run starts two minutes
after the previous one finishes, so runs will not overlap. Use
`systemctl list-timers` to see when it will next fire.

## SNMP Extends

Both extends print a
[LibreNMS style](https://docs.librenms.org/Developing/Application-Notes/) JSON
return on stdout and are meant to be wired into snmpd as an extend. `-Z` turns
off the conditional GZip+Base64 compression, which is worth having while
checking the output by hand. Run either with `-h` for the full switch list, and
see their PODs for what every stat key means.

### suricata_extract_submit_extend

Stats for `suricata_extract_submit`, so it belongs on the Suricata sensor
alongside it rather than on the CAPE box. Add to snmpd.conf.

```
extend suricata-extract /usr/local/bin/suricata_extract_submit_extend
```

It reads the stats `suricata_extract_submit` writes out, so the paths have to
agree with that side's `stats_file` and `stats_dir`.

- `-c <stats file>` :: The stats file, matching `stats_file`. Defaults to
  '/var/cache/suricata_extract_submit_stats.json'.

- `-d <stats dir>` :: The stats dir, matching `stats_dir`. Defaults to
  '/var/cache/suricata_extract_submit_stats'.

- `-r <seconds>` :: How far back to look for the entry to compute the deltas
  against. A larger value needs correspondingly older history to find one, and
  the deltas come back zeroed when it does not. Defaults to 300.

### nergal_extend

Stats for `nergal`, computed by reading the incoming JSONs, so it belongs
wherever nergal keeps its incoming dir.

```
extend nergal /usr/local/bin/nergal_extend
```

The extend name above is only an example, as it is whatever the LibreNMS
application expects.

- `-m <dir>` :: The incoming JSON dir, that being the 'json' subdirectory under
  nergal's `incoming`. Defaults to '/malware/client-incoming/json/'.
