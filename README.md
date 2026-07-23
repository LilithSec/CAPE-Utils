# CAPE-Utils

Utilities for use with CAPEv2.

## Installation

### FreeBSD

Only relevant for `suricata_extract_submit`.

```
pkg install p5-App-cpanminus
cpanm CAPE::Utils
```

## Debian/Ubuntu

For Debian, only `suricata_extract_submit` is relevant.

```
apt-get install cpanminus
cpanm CAPE::Utils
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

The defaults are as below, which out of the box, it will work by
default with CAPEv2 in it's default config.

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
# 0/1 if fail should be allowed to run with out a where statement
fail_all=0
# colums to use for pending table show
pending_columns=id,target,package,timeout,ET,route,options,clock,added_on
# colums to use for runniong table show
running_columns=id,target,package,timeout,ET,route,options,clock,added_on,started_on,machine
# colums to use for tasks table
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
# the api key to for with nergal
#apikey=
# how to auth for nergal (ip/apikey/both/either)
auth=ip
# comma seperated list of allowed subnets for nergal
subnets=192.168.0.0/16,127.0.0.1/8,::1/128,172.16.0.0/12,10.0.0.0/8
# how to auth for the nergal results endpoint (ip/apikey/both/either)
results_auth=ip
# the api key for the nergal results endpoint
#results_apikey=
# comma seperated list of allowed subnets for the nergal results endpoint
results_subnets=192.168.0.0/16,127.0.0.1/8,::1/128,172.16.0.0/12,10.0.0.0/8
# incoming dir to use for nergal
incoming=/malware/client-incoming
```

### nergal

If cape_utils has been configured and is working, this just requires
the 'incoming' setting configured.

The 'incoming' setting is a directory in which incoming files are placed
for submission. By default this is '/malware/client-incoming'. The
submission data JSON, checksum store, and task-to-JSON links are all kept
in subdirectories beneath it. See L<CAPE::Utils::Nergal/"INCOMING DIR
STRUCTURE"> for the layout.

By default this will auth of the remote IP via the setting 'subnets',
which by default is
'192.168.0.0/16,127.0.0.1/8,::1/128,172.16.0.0/12,10.0.0.0/8'. This
value is a comma seperated string of subnets to accept submissions
from.

To enable the use of a API key, set the value of 'apikey' and set 'auth'
to 'apikey' (key only), 'both' (key and IP), or 'either' (key or IP).

Using the provided systemd service file, you will also need to create
'/usr/local/etc/nergal.env' and configure it akin to below.

```
LISTEN_ON="http://192.168.14.15:8080"
```

The service runs as the user and group 'cape' via the unit's 'User='
and 'Group=' directives. If you need it to run as a different user, edit
those in 'systemd/nergal.service' rather than setting an environment
variable.

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
