#!/usr/bin/perl -w
# Pod::Usage fails with --man if running in taint mode
# See bottom of file for license and copyright information
use strict;
use warnings;
use version;
our $VERSION = qv('0.1.1');

use re 'taint';
use FindBin();
use File::Spec();
use Config;
use Cwd;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;

my %options;       # Getopt parses options into this hash
my $debuglevel;    # Keep adding --debug to increase debuglevel

##############
# Erm... well, this bit used to resemble bits of pseudo-install.pl
my @extensions_path;          # not used atm but might be handy :)
my $extensions_dir;           # string form of the above
my $foswikilib_dir;           # /path/to/foswiki/core/lib
my $base_dir;                 # /path/to/foswiki/core
my @base_path;                # array form of the above
my $parent_dir;               # /path/to/foswiki
my $fetchedExtensions_dir;    # /path/to/foswiki

BEGIN {
    no re 'taint';
    $FindBin::Bin =~ /(.*)/;    # core dir
    $base_dir = $1;
    ( $ENV{FOSWIKI_LIBS} || File::Spec->catdir( $base_dir, 'lib' ) ) =~ /(.*)/;
    $foswikilib_dir = $1;
    use re 'taint';
    my ( $volume, $directories, $file ) = File::Spec->splitpath( $base_dir, 1 );
    @base_path = File::Spec->splitdir($directories);
    $parent_dir =
      File::Spec->catdir( @base_path[ 0 .. ( scalar(@base_path) - 2 ) ] );
    $fetchedExtensions_dir = $parent_dir;
    $extensions_dir = $ENV{FOSWIKI_EXTENSIONS} || '';
    $extensions_dir .=
        $Config::Config{path_sep}
      . File::Spec->catfile( $base_dir, 'twikiplugins' )
      . $Config::Config{path_sep} . '.'
      . $Config::Config{path_sep}
      . $parent_dir;
    @extensions_path =
      grep { -d $_ } split( /$Config::Config{path_sep}/, $extensions_dir );

    ### Set up INC path and some Foswiki env
    unshift @INC, split( /:/, $foswikilib_dir );

    # Default repo config
    require(
        File::Spec->catfile(
            qw(Foswiki Plugins FoswikiGitDevPlugin Config.spec))
    );

    # Get customised repo config (and bin/ path)
    require('LocalSite.cfg');
    ### Most of this isn't needed, unless we want to fire up a full session...
   #   require( File::Spec->catfile( $Foswiki::cfg{ScriptDir}, 'setlib.cfg' ) );
   #	$Foswiki::cfg{Engine} = 'Foswiki::Engine::CLI';
   #	require Carp;
   #	$SIG{__DIE__} = \&Carp::confess;
   #	$ENV{FOSWIKI_ACTION} = 'view';
    ### initialise the bits we need (don't need a full session after all)
    require Foswiki::Plugins::FoswikiGitDevPlugin::CLI;
    Foswiki::Plugins::FoswikiGitDevPlugin::CLI::init( $fetchedExtensions_dir,
        $foswikilib_dir );
}

sub exec_options {
    my (%opts) = @_;
    my @actions;
    my $success  = 0;
    my %dispatch = (
        help => sub { pod2usage(1); return 1; },
        man => sub { pod2usage( -exitstatus => 0, -verbose => 2 ); return 1; },
        usage => sub { pod2usage(2); return 1; },
        version => sub { Getopt::Long::VersionMessage(); return 1; },
        report    => \&Foswiki::Plugins::FoswikiGitDevPlugin::CLI::doReport,
        fetch     => \&Foswiki::Plugins::FoswikiGitDevPlugin::CLI::doFetch,
        update    => \&Foswiki::Plugins::FoswikiGitDevPlugin::CLI::doUpdate,
        checkout  => \&Foswiki::Plugins::FoswikiGitDevPlugin::CLI::doCheckout,
        docommand => \&Foswiki::Plugins::FoswikiGitDevPlugin::CLI::doCommand
    );

    @actions = keys %opts;
    if ( not( scalar(@actions) ) ) {
        pod2usage(2);
    }
    elsif ( scalar(@actions) > 1 ) {
        print STDERR
          "ERROR:\tInvocation may only have 1 action, but you specified "
          . scalar(@actions) . ":\n\t"
          . join( ', ', @actions ) . "\n";
        pod2usage(2);
    }
    else {
        while ( my ( $action, $args ) = each(%opts) ) {
            writeDebug( "The action is '$action' with args: " . Dumper($args),
                'exec_options', 3 );
            if ( exists $dispatch{$action} ) {
                $success = $dispatch{$action}->($args);
            }
            else {
                print STDERR "ERROR: $action not implemented\n";
            }
        }
    }

    return $success;
}

###############################################################################

GetOptions(
    \%options,          'help+',
    'man+',             'usage+',
    'version+',         'debug+',
    'report=s@{,}',     'fetch=s@{,}',
    'update=s@{,}',     'checkout=s@{2,}',
    'docommand=s@{2,}', 'setupremote=s@{,}'
) or pod2usage(2);

writeDebug( 'Options: ' . Dumper( \%options ), 'main', 3 );

$debuglevel = $options{debug};
delete $options{debug};
exec_options(%options);

sub writeDebug {
    my ( $message, $method, $level ) = @_;

    Foswiki::Plugins::FoswikiGitDevPlugin::writeDebug( $message, $method,
        $level, __PACKAGE__, $debuglevel || $options{debug} );

    return;
}

1;

__DATA__

=head1 NAME

extensionsdo.pl - CLI tool to FoswikiGitDevPlugin

=head1 DESCRIPTION

Maintain a series of (git) repositories which each contain a single extension.
See L<http://foswiki.org/Development/MoveCodeRepositoryToGit>

=head1 USAGE

./extensionsdo.pl --<action> [action arguments] <modules>...

./extensionsdo.pl --help for more information

=head1 OPTIONS

=over

=item --<action>s:

=over

=item --report [<state>]

report state (ahead, behind, current, dirty, missing, remoteless) of extension
repositories or list only those with specified state(s) (--report may be
repeated)

B<NOTE:> 'missing' state is mainly useful with <modules> spec of 'universe'

=item --fetch

fetch from remote(s) - doesn't change work tree

=item --update

try to update work tree with latest from remote(s)

=item --checkout <ref>

on each extension repository, checkout some branch/ref

=item --docommand <command>

execute some command at the root of each extension repository

=item --setupremote

consult the configured repository sites to find one that knows about the
specified extension name and make it a remote for that extension's repository

=back

=item <modules>...

A list (separated by spaces) of extension names, or one of the following:

=over

=item all - all existing (local) extensions

=item default - all default (core) extensions

=item universe - all extensions from all remotes

=item developer - all default (core) and developer extensions

=back

=item --usage

=item --help

=item --man

=item --version

=item --debug

=back

=head1 EXAMPLES

=over

=item Update existing extensions:

 ./extensionsdo.pl --update all

=item Update SomePlugin - if missing, do initial fetch & checkout:

 ./extensionsdo.pl --update SomePlugin

=item Download all extensions from all remotes:

 ./extensionsdo.pl --fetch universe

=item Switch default extensions to Release01x01 branch:

 ./extensionsdo.pl --checkout Release01x01 default

=item Report all local extensions that are ahead or dirty

 ./extensionsdo.pl --report ahead dirty all

=back

=head1 AUTHOR

L<Paul.W.Harvey@csiro.au>, Foswiki Contributors. Foswiki Contributors are
listed in the AUTHORS file in the root of this distribution.

=head1 BUGS AND LIMITATIONS

L<http://foswiki.org/Tasks/FoswikiGitDevPlugin>

=over

=item Feedback and error handling are shockingly absent, so this should be
considered alpha quality software until that's fixed

=item Arbitrarily configured, hand-crafted git repos will work fine, but there
are some embarassing assumptions when it comes to the 'remote sites' feature(s).
'remote sites' feature allow us to resolve an extension name into a repo URL
(possibly with svn remote as well), and enables a new correctly configured,
fetched & checked-out git repo to be created automagically just from a name.
So, git repos for extensions derived from a configured 'remote site':

=over

=item * which have a git remote, will call that remote 'origin', and

=item * which have a git-svn remote, will call that svn-remote "svn"

=back

=item Path magic (extensions dir, etc.) not as smart as pseudo-install

=item extensionsdo, pseudo-install serve somewhat overlapping purposes

=item What about extensions as git submodules in super-projects?

=item Lacking features to help git integration with TasksContrib

=back

=head1 LICENSE AND COPYRIGHT

Foswiki - The Free and Open Source Wiki, L<http://foswiki.org/>

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
