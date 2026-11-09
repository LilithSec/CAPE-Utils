package CAPE::Utils::Cmd::Command::completion;

use strict;
use warnings;
use parent 'App::Cmd::Command';

our $VERSION = '0.1.0';

# What to complete for the value of a option that takes one. Keyed by the
# option's primary name, being the first name in its spec, either as
# "<subcommand>:<name>" for one subcommand or just "<name>" for all of them.
# The subcommand specific key wins.
#
# A value is one of...
#     - file :: file names
#     - dir :: directory names
#     - an array ref :: the fixed list of values it accepts
#
# Options taking a value that are not listed here complete nothing, which keeps
# the shell from offering option names or files where a task ID is wanted.
my %option_value_hints = (
	'ini'             => 'file',
	'exec:dir'        => 'dir',
	'munge:report'    => 'file',
	'tasks:direction' => [ 'asc', 'desc' ],
);

# What to complete for the positional arguments of a subcommand. Subcommands not
# listed take none, or take ones there is no sensible completion for.
#
# A value is one of...
#     - file :: file and directory names
#     - subcommand :: cape_utils subcommand names
#     - command :: options until "--", then a command name followed by files
#     - passthrough :: options until "--", then files
#     - an array ref :: the fixed list of values it accepts
my %positional_hints = (
	submit     => 'file',
	exec       => 'command',
	poetry     => 'passthrough',
	uv         => 'passthrough',
	help       => 'subcommand',
	completion => [ 'bash', 'zsh' ],
);

# Used in place of the abstract for subcommands whose abstract App::Cmd can not
# work out, which is the case for ones that lack a POD NAME section such as the
# version command inherited from App::Cmd.
my %fallback_descriptions = ( version => 'show the version', );

# The one line summary App::Cmd shows beside this sub command in the listing
# printed by "cape_utils commands" and by the top level usage output.
#
# Args:
#     - none
#
# Returns the summary as a string, with no trailing newline.
#
#     print CAPE::Utils::Cmd::Command::completion->abstract . "\n";
sub abstract {
	return 'print a bash or zsh completion script';
}

# The usage block App::Cmd prints for "cape_utils help completion" and on a
# usage error, covering where to put the script for each shell.
#
# Args:
#     - none
#
# Returns the usage text as a multi line string ending in a newline.
#
#     print CAPE::Utils::Cmd::Command::completion->usage_desc;
sub usage_desc {
	return 'cape_utils completion <bash|zsh>

Print a completion script for cape_utils for the given shell. It is generated
from the installed subcommands and their options, so regenerate it after
upgrading.

To install it for bash, put it in the bash-completion completions dir...

    FreeBSD :: cape_utils completion bash > /usr/local/share/bash-completion/completions/cape_utils
    Debian :: cape_utils completion bash > /usr/share/bash-completion/completions/cape_utils

Or add this to ~/.bashrc...

    source <(cape_utils completion bash)

For zsh, put it in a dir in $fpath as _cape_utils...

    FreeBSD :: cape_utils completion zsh > /usr/local/share/zsh/site-functions/_cape_utils
    Debian :: cape_utils completion zsh > /usr/share/zsh/vendor-completions/_cape_utils

Or add this to ~/.zshrc after compinit...

    source <(cape_utils completion zsh)
';
} ## end sub usage_desc

# Checks that exactly one supported shell was asked for.
#
# Args:
#     - opt :: The options hash ref built from opt_spec, unused here. Required,
#       and supplied by App::Cmd.
#
#     - args :: An array ref of the positional arguments, which should hold just
#       the shell name, 'bash' or 'zsh'. Required, and supplied by App::Cmd.
#
# Returns nothing when the arguments are usable. Calls usage_error, which prints
# the usage and exits non zero, when they are not.
#
#     $ cape_utils completion fish
#     Unsupported shell "fish", must be bash or zsh
sub validate_args {
	my ( $self, $opt, $args ) = @_;

	if ( !defined( $args->[0] ) ) {
		$self->usage_error('No shell specified');
	}
	if ( defined( $args->[1] ) ) {
		$self->usage_error('Only one shell may be specified');
	}
	if ( $args->[0] ne 'bash' && $args->[0] ne 'zsh' ) {
		$self->usage_error( 'Unsupported shell "' . $args->[0] . '", must be bash or zsh' );
	}

	return;
} ## end sub validate_args

# Prints the completion script for the requested shell to STDOUT.
#
# Args:
#     - opt :: The options hash ref built from opt_spec, unused here. Required,
#       and supplied by App::Cmd.
#
#     - args :: An array ref holding the shell name, 'bash' or 'zsh', as checked
#       by validate_args. Required, and supplied by App::Cmd.
#
# Returns nothing, the point of it being what it prints.
#
#     $ cape_utils completion zsh > /usr/local/share/zsh/site-functions/_cape_utils
sub execute {
	my ( $self, $opt, $args ) = @_;

	my $subcommands = $self->subcommand_specs( $self->app );

	if ( $args->[0] eq 'bash' ) {
		print $self->bash_script($subcommands);
	} else {
		print $self->zsh_script($subcommands);
	}

	return;
} ## end sub execute

# Collects what the completion scripts need to know about each subcommand, being
# its name, description, options, and what its positional arguments are, by
# asking App::Cmd for the subcommands and each one for its opt_spec.
#
# Names App::Cmd registers that start with a dash, such as --help and
# --version, are aliases and are skipped.
#
# Args:
#     - app :: The App::Cmd application object, a CAPE::Utils::Cmd. Required.
#
# Returns a array ref of hash refs sorted by name, one per subcommand, as below.
#
#     - name :: The subcommand name, such as 'exec'.
#
#     - description :: Its one line abstract.
#
#     - options :: A array ref of option hash refs as returned by
#       parse_option_spec.
#
#     - positional :: The positional hint from %positional_hints, or undef.
#
#     my $subcommands = CAPE::Utils::Cmd::Command::completion->subcommand_specs( CAPE::Utils::Cmd->new );
#     # [ { name => 'eve', description => 'invoke CAPE::Utils->eve_process',
#     #     options => [ { names => [ '--ini', '-i' ], ... } ], positional => undef }, ... ]
sub subcommand_specs {
	my ( $class, $app ) = @_;

	my @subcommands;
	foreach my $name ( sort( grep { !/^-/ } $app->command_names ) ) {
		my $plugin = $app->plugin_for($name);

		my $description = $plugin->abstract;
		if ( defined( $fallback_descriptions{$name} ) ) {
			$description = $fallback_descriptions{$name};
		}

		my @options;
		foreach my $spec ( $plugin->opt_spec($app) ) {
			# opt_spec may hold strings or empty array refs as section headers
			if ( ref($spec) ne 'ARRAY' || !defined( $spec->[0] ) || $spec->[0] eq '' ) {
				next;
			}
			push( @options, $class->parse_option_spec( $name, $spec ) );
		}

		push(
			@subcommands,
			{
				name        => $name,
				description => $description,
				options     => \@options,
				positional  => $positional_hints{$name},
			}
		);
	} ## end foreach my $name ( sort( grep { !/^-/ } $app->command_names...))

	return \@subcommands;
} ## end sub subcommand_specs

# Turns one Getopt::Long::Descriptive option spec into what the completion
# scripts need.
#
# Single letter names become "-x" and longer ones "--xxx", as App::Cmd runs
# Getopt::Long with bundling. A negatable option, one ending in "!", also gets a
# "--no-xxx" form for each of its long names.
#
# Args:
#     - subcommand :: The name of the subcommand the option belongs to, used for
#       looking up its value hint. Such as 'exec'. Required.
#
#     - spec :: The array ref from opt_spec, the first item being the spec string
#       such as 'dir|d=s' and the second its description. Required.
#
# Returns a hash ref as below.
#
#     - names :: A array ref of every way to write it, such as [ '--dir', '-d' ].
#
#     - description :: The description from the spec, or '' if it has none.
#
#     - takes_value :: 0/1 for if a value must follow it. Optional values, ':s'
#       and the like, count as 0 as the next word may not be the value.
#
#     - value_hint :: When takes_value is 1, the hint from %option_value_hints,
#       or 'none' if it has none. Undef when takes_value is 0.
#
#     my $option = CAPE::Utils::Cmd::Command::completion->parse_option_spec(
#         'exec', [ 'dir|d=s', 'dir to run the command from' ] );
#     # { names => [ '--dir', '-d' ], description => 'dir to run the command from',
#     #   takes_value => 1, value_hint => 'dir' }
sub parse_option_spec {
	my ( $class, $subcommand, $spec ) = @_;

	# the names are everything up to the type, being "=s", ":i", "!", "+", etc
	my ( $names_part, $type ) = $spec->[0] =~ /^([^=:!+]+)(.*)$/;
	my @aliases = split( /\|/, $names_part );

	my @names;
	foreach my $alias (@aliases) {
		push( @names, length($alias) == 1 ? '-' . $alias : '--' . $alias );
	}
	if ( $type eq '!' ) {
		push( @names, map { '--no-' . $_ } grep { length($_) > 1 } @aliases );
	}

	my $takes_value = $type =~ /^=/ ? 1 : 0;

	my $value_hint;
	if ($takes_value) {
		my $primary = $aliases[0];
		$value_hint = $option_value_hints{ $subcommand . ':' . $primary } // $option_value_hints{$primary} // 'none';
	}

	return {
		names       => \@names,
		description => defined( $spec->[1] ) ? $spec->[1] : '',
		takes_value => $takes_value,
		value_hint  => $value_hint,
	};
} ## end sub parse_option_spec

# Builds the bash completion script.
#
# The subcommand data goes into associative arrays at the top of the script, and
# a fixed _cape_utils function does the completing from them, so the generated
# part is only data. The arrays are declared with -g as bash-completion sources
# completion files from inside a function when lazy loading them.
#
# A hint in the arrays is written as a string, with a list of fixed values
# written as "choice:<value> <value>...".
#
# Args:
#     - subcommands :: The array ref returned by subcommand_specs. Required.
#
# Returns the script as a string.
#
#     print CAPE::Utils::Cmd::Command::completion->bash_script(
#         CAPE::Utils::Cmd::Command::completion->subcommand_specs( CAPE::Utils::Cmd->new ) );
sub bash_script {
	my ( $class, $subcommands ) = @_;

	my $options_lines    = '';
	my $values_lines     = '';
	my $positional_lines = '';
	foreach my $subcommand ( @{$subcommands} ) {
		my $name = $subcommand->{name};

		my @option_names = map { @{ $_->{names} } } @{ $subcommand->{options} };
		my $positional   = $subcommand->{positional} // '';
		if ( $positional eq 'command' || $positional eq 'passthrough' ) {
			push( @option_names, '--' );
		}
		$options_lines .= "\t['" . $name . "']='" . join( ' ', @option_names ) . "'\n";

		foreach my $option ( @{ $subcommand->{options} } ) {
			if ( !$option->{takes_value} ) {
				next;
			}
			my $hint = $option->{value_hint};
			if ( ref($hint) eq 'ARRAY' ) {
				$hint = 'choice:' . join( ' ', @{$hint} );
			}
			foreach my $option_name ( @{ $option->{names} } ) {
				$values_lines .= "\t['" . $name . ':' . $option_name . "']='" . $hint . "'\n";
			}
		} ## end foreach my $option ( @{ $subcommand->{options} ...})

		if ( ref($positional) eq 'ARRAY' ) {
			$positional = 'choice:' . join( ' ', @{$positional} );
		}
		if ( $positional ne '' ) {
			$positional_lines .= "\t['" . $name . "']='" . $positional . "'\n";
		}
	} ## end foreach my $subcommand ( @{$subcommands} )

	my $subcommand_names = join( ' ', map { $_->{name} } @{$subcommands} );

	return '# bash completion for cape_utils
# generated by "cape_utils completion bash", regenerate it after upgrading CAPE::Utils

_cape_utils_subcommands=\'' . $subcommand_names . '\'

# the options each subcommand takes
declare -gA _cape_utils_options=(
' . $options_lines . ')

# what to complete for the value of "<subcommand>:<option>"
declare -gA _cape_utils_option_values=(
' . $values_lines . ')

# what to complete for the positional args of a subcommand
declare -gA _cape_utils_positionals=(
' . $positional_lines . ')

# Fills COMPREPLY for a hint of file, dir, subcommand, or choice:<values>.
# Anything else, such as none, completes nothing.
_cape_utils_complete_hint() {
	local hint=$1 current=$2
	case $hint in
		file)
			compopt -o filenames 2>/dev/null
			mapfile -t COMPREPLY < <(compgen -f -- "$current")
			;;
		dir)
			compopt -o filenames 2>/dev/null
			mapfile -t COMPREPLY < <(compgen -d -- "$current")
			;;
		subcommand)
			mapfile -t COMPREPLY < <(compgen -W "$_cape_utils_subcommands" -- "$current")
			;;
		choice:*)
			mapfile -t COMPREPLY < <(compgen -W "${hint#choice:}" -- "$current")
			;;
	esac
}

_cape_utils() {
	local current=${COMP_WORDS[COMP_CWORD]}
	local previous=${COMP_WORDS[COMP_CWORD-1]}
	local subcommand=\'\' dashdash_index=0 index word
	COMPREPLY=()

	# the subcommand is the first word that is not an option, and a "--" after
	# it ends the options for cape_utils
	for (( index = 1; index < COMP_CWORD; index++ )); do
		word=${COMP_WORDS[index]}
		if [[ -z $subcommand ]]; then
			[[ $word != -* ]] && subcommand=$word
		elif [[ $word == -- ]]; then
			dashdash_index=$index
			break
		fi
	done

	if [[ -z $subcommand ]]; then
		_cape_utils_complete_hint subcommand "$current"
		return
	fi

	local positional=${_cape_utils_positionals[$subcommand]}

	# past "--" is the command exec runs, or args for poetry/uv
	if (( dashdash_index )); then
		if [[ $positional == command ]] && (( COMP_CWORD == dashdash_index + 1 )); then
			mapfile -t COMPREPLY < <(compgen -c -- "$current" | sort -u)
		else
			_cape_utils_complete_hint file "$current"
		fi
		return
	fi

	local value_hint=${_cape_utils_option_values[$subcommand:$previous]}
	if [[ -n $value_hint ]]; then
		_cape_utils_complete_hint "$value_hint" "$current"
		return
	fi

	if [[ $current == -* ]]; then
		mapfile -t COMPREPLY < <(compgen -W "${_cape_utils_options[$subcommand]}" -- "$current")
		return
	fi

	_cape_utils_complete_hint "$positional" "$current"
}

complete -F _cape_utils cape_utils
';
} ## end sub bash_script

# Builds the zsh completion script.
#
# Each subcommand gets its own _arguments call, built from its options, so zsh
# shows the option descriptions and keeps mutually exclusive names, such as -d
# and --dir, from both being offered once one is used.
#
# The script works both from a file named _cape_utils in $fpath, where the
# #compdef line registers it, and when sourced, where it registers itself via
# compdef.
#
# Args:
#     - subcommands :: The array ref returned by subcommand_specs. Required.
#
# Returns the script as a string.
#
#     print CAPE::Utils::Cmd::Command::completion->zsh_script(
#         CAPE::Utils::Cmd::Command::completion->subcommand_specs( CAPE::Utils::Cmd->new ) );
sub zsh_script {
	my ( $class, $subcommands ) = @_;

	# escapes text for going inside a single quoted _arguments spec, which on
	# top of the shell quoting treats [, ], and : as special
	my $escape = sub {
		my ($text) = @_;
		$text =~ s/([\\\[\]:])/\\$1/g;
		$text =~ s/'/'\\''/g;
		return $text;
	};

	my %value_actions = ( file => '_files', dir => '_files -/', none => ' ' );

	my $describe_lines = '';
	my $case_branches  = '';
	foreach my $subcommand ( @{$subcommands} ) {
		$describe_lines
			.= "\t\t\t\t'" . $subcommand->{name} . ':' . $escape->( $subcommand->{description} ) . "'\n";

		my @specs;
		foreach my $option ( @{ $subcommand->{options} } ) {
			my @names     = @{ $option->{names} };
			my $exclusion = @names > 1 ? '(' . join( ' ', @names ) . ')' : '';

			my $value_part = '';
			if ( $option->{takes_value} ) {
				my $hint   = $option->{value_hint};
				my $action = ref($hint) eq 'ARRAY' ? '(' . join( ' ', @{$hint} ) . ')' : $value_actions{$hint};
				( my $message = $names[0] ) =~ s/^-+//;
				$value_part = ':' . $message . ':' . $action;
			}

			foreach my $option_name (@names) {
				my $value_marker = '';
				if ( $option->{takes_value} ) {
					$value_marker = $option_name =~ /^--/ ? '=' : '+';
				}
				push( @specs,
						  $exclusion
						. $option_name
						. $value_marker . '['
						. $escape->( $option->{description} ) . ']'
						. $value_part );
			} ## end foreach my $option_name (@names)
		} ## end foreach my $option ( @{ $subcommand->{options} ...})

		my $positional = $subcommand->{positional} // '';
		if ( ref($positional) eq 'ARRAY' ) {
			push( @specs, '1:value:(' . join( ' ', @{$positional} ) . ')' );
		} elsif ( $positional eq 'file' ) {
			push( @specs, '*:file:_files' );
		} elsif ( $positional eq 'subcommand' ) {
			push( @specs, '1:subcommand:(' . join( ' ', map { $_->{name} } @{$subcommands} ) . ')' );
		}

		$case_branches .= "\t\t\t\t" . $subcommand->{name} . ")\n";

		# past "--" is the command exec runs or args for poetry/uv, so drop the
		# words up to it and complete what is left on its own, as _arguments
		# would otherwise hand "--" to _normal as the command name
		if ( $positional eq 'command' || $positional eq 'passthrough' ) {
			my $rest_action = $positional eq 'command' ? '_normal' : '_files';
			$case_branches
				.= "\t\t\t\t\tlocal dashdash=\${words[(i)--]}\n"
				. "\t\t\t\t\tif (( dashdash < CURRENT )); then\n"
				. "\t\t\t\t\t\tshift \$dashdash words\n"
				. "\t\t\t\t\t\t(( CURRENT -= dashdash ))\n"
				. "\t\t\t\t\t\t"
				. $rest_action . "\n"
				. "\t\t\t\t\t\treturn\n"
				. "\t\t\t\t\tfi\n";
			push( @specs, '(-)--[end of the cape_utils options]' );
		} ## end if ( $positional eq 'command' || $positional...)

		if (@specs) {
			$case_branches .= "\t\t\t\t\t_arguments -s -S \\\n"
				. join( " \\\n", map { "\t\t\t\t\t\t'" . $_ . "'" } @specs ) . "\n";
		} else {
			$case_branches .= "\t\t\t\t\t_message 'no arguments'\n";
		}
		$case_branches .= "\t\t\t\t\t;;\n";
	} ## end foreach my $subcommand ( @{$subcommands} )

	return '#compdef cape_utils
# zsh completion for cape_utils
# generated by "cape_utils completion zsh", regenerate it after upgrading CAPE::Utils

_cape_utils() {
	local curcontext=$curcontext state state_descr line
	typeset -A opt_args

	_arguments -C \\
		\'1:subcommand:->subcommand\' \\
		\'*::argument:->argument\'

	case $state in
		subcommand)
			local -a subcommands=(
' . $describe_lines . '			)
			_describe -t subcommands \'cape_utils subcommand\' subcommands
			;;
		argument)
			curcontext=${curcontext%:*:*}:cape_utils-$words[1]:
			case $words[1] in
' . $case_branches . '			esac
			;;
	esac
}

if [[ $zsh_eval_context[-1] == loadautofunc ]]; then
	_cape_utils "$@"
else
	compdef _cape_utils cape_utils
fi
';
} ## end sub zsh_script

1;
