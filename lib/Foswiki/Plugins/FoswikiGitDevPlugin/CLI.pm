# See bottom of file for default license and copyright information

=begin TML

---+ package FoswikiGitDevPlugin::CLI

API for the CLI? Does final sanity checks and expansion, interpretation of
command line arguments before building the variables necessary to pass on to
the 'real' worker methods.

This could probably have remained in extensionsdo.pl, but oh well..

=cut

package Foswiki::Plugins::FoswikiGitDevPlugin::CLI;
use strict;
use warnings;

use Assert;
use Foswiki::Plugins::FoswikiGitDevPlugin();
use File::Spec();    # For listDefaultExtensionNames()
use Data::Dumper;

my $lib_dir;
my $debuglevel;
my $fetchedExtensions_dir;

sub init {
    ( $fetchedExtensions_dir, $lib_dir, $debuglevel ) = @_;

    ASSERT( defined $fetchedExtensions_dir );
    ASSERT( defined $lib_dir );

    return;
}

sub doReportParseArg {
    my ( $arg, $found ) = @_;
    my %allowed_states =
      Foswiki::Plugins::FoswikiGitDevPlugin::Extension::getReportStates();
    my %special_states =
      Foswiki::Plugins::FoswikiGitDevPlugin::Extension::getSpecialReportStates(
      );
    my $invalid = 0;

    writeDebug(
        "arg: $arg, allowed: "
          . join( ', ', keys %allowed_states )
          . ", special: "
          . join( ', ', keys %special_states ),
        'doReportParseArg', 4
    );
    while ( my ( $key, $states ) = each %special_states ) {
        if ( $arg eq $key ) {
            $arg = $states;
        }
    }
    foreach my $char ( split( //, $arg ) ) {
        if ( not exists $allowed_states{$char} ) {
            $invalid = 1;
        }
        else {
            $found->{states}{$char} = 1;
        }
    }
    if ( $arg eq '+' ) {
        $invalid = 0;
        $found->{all} = 1;
    }
    writeDebug( "found: " . join( ', ', keys %{$found} ) . " invalid: $invalid",
        'doReportParseArg', 4 );

    return not $invalid;
}

sub doReport {
    my ($args) = @_;
    my %reportargs;
    my @extensions;

    ASSERT( scalar( @{$args} ) > 0 );
    Foswiki::Plugins::FoswikiGitDevPlugin::init( $fetchedExtensions_dir,
        $debuglevel );
    foreach my $arg ( @{$args} ) {
        my $valid = doReportParseArg( $arg, \%reportargs );

        if ( not $valid ) {
            push( @extensions, $arg );
        }
    }
    @extensions = expandExtensions( \@extensions );
    if ( not scalar( keys %{ $reportargs{states} } ) ) {
        $reportargs{states} =
          { Foswiki::Plugins::FoswikiGitDevPlugin::Extension::getReportStates()
          };
    }
    writeDebug(
        "Reporting ($reportargs{all}) "
          . join( ', ', keys %{ $reportargs{states} } )
          . ' for these: '
          . join( ', ', @extensions ),
        'doReport', 3
    );
    $reportargs{extensions} = \@extensions;
    Foswiki::Plugins::FoswikiGitDevPlugin::report(%reportargs);

    return 1;
}

sub doFetch {
    my ($args) = @_;
    my @extensions;

    ASSERT( scalar( @{$args} ) > 0 );
    Foswiki::Plugins::FoswikiGitDevPlugin::init( $fetchedExtensions_dir,
        $debuglevel );

    @extensions = expandExtensions($args);

    writeDebug( "Fetching " . join( ', ', sort(@extensions) ), 'doFetch', 3 );
    Foswiki::Plugins::FoswikiGitDevPlugin::fetch( extensions => \@extensions );

    return 1;
}

sub doUpdate {
    my ($args) = @_;
    my @extensions;

    ASSERT( scalar( @{$args} ) > 0 );

    Foswiki::Plugins::FoswikiGitDevPlugin::init( $fetchedExtensions_dir,
        $debuglevel );
    @extensions = expandExtensions($args);

    writeDebug( "Updating " . join( ', ', sort(@extensions) ), 'doUpdate', 3 );
    Foswiki::Plugins::FoswikiGitDevPlugin::update( extensions => \@extensions );

    return 1;
}

sub doCheckout {
    my ($args) = @_;
    my $ref;
    my @extensions;

    ASSERT( scalar( @{$args} ) > 1 );
    Foswiki::Plugins::FoswikiGitDevPlugin::init( $fetchedExtensions_dir,
        $debuglevel );
    $ref = $args->[0];

    # Take a slice omitting the first command element
    @extensions = @{$args}[ 1 .. ( scalar( @{$args} ) - 1 ) ];
    @extensions = expandExtensions( \@extensions );

    writeDebug( "Checking out '$ref' on these: " . join( ', ', @extensions ),
        'doCheckout', 3 );
    Foswiki::Plugins::FoswikiGitDevPlugin::checkout(
        extensions => \@extensions,
        ref        => $ref
    );

    return 1;

}

sub doCommand {
    my ($args) = @_;
    my $command;
    my @extensions;

    ASSERT( scalar( @{$args} ) > 1 );
    Foswiki::Plugins::FoswikiGitDevPlugin::init( $fetchedExtensions_dir,
        $debuglevel );
    $command = $args->[0];

    # Take a slice omitting the first command element
    @extensions = @{$args}[ 1 .. ( scalar( @{$args} ) - 1 ) ];
    @extensions = expandExtensions( \@extensions );

    writeDebug( "Doing '$command' on these: " . Dumper( \@extensions ),
        'doCommand', 3 );

    return 1;
}

sub expandExtensions {
    my ($args) = @_;
    my %special = (
        all => \&Foswiki::Plugins::FoswikiGitDevPlugin::listLocalExtensionNames,
        universe =>
          \&Foswiki::Plugins::FoswikiGitDevPlugin::listUniverseExtensionNames,
        developer => \&listDeveloperExtensionNames,
        default   => \&listDefaultExtensionNames
    );
    my @extensions;

    ASSERT( ref($args) eq 'ARRAY' );
    ASSERT( scalar( @{$args} ) > 0 );
    if ( exists $special{ $args->[0] } ) {
        writeDebug( "Expanding $args->[0]", 'expandExtensions', 3 );
        @extensions = $special{ $args->[0] }->();
    }
    else {
        @extensions = @{$args};
    }

    return @extensions;
}

sub listDeveloperExtensionNames {
    return ( listDefaultExtensionNames(),
        qw(BuildContrib TestFixturePlugin UnitTestContrib) );
}

# From pseudo-install.pl
sub listDefaultExtensionNames {
    my @modules;
    my @lib_path = File::Spec->splitdir($lib_dir);
    my $manifest_dirpath = File::Spec->catfile( @lib_path, 'MANIFEST' );

    writeDebug( "MANIFEST at $manifest_dirpath",
        'listDefaultExtensionNames', 3 );

    open my $f, "<", $manifest_dirpath
      or die "Could not open MANIFEST: $!";
    local $/ = "\n";
    @modules =
      map { /(\w+)$/; $1 }
      grep { /^!include/ } <$f>;
    close $f;

    return @modules;
}

sub writeDebug {
    my ( $message, $method, $level ) = @_;

    return Foswiki::Plugins::FoswikiGitDevPlugin::writeDebug( $message, $method,
        $level, __PACKAGE__, $debuglevel );
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2011 Foswiki Contributors. Foswiki Contributors
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
