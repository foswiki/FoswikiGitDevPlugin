# See bottom of file for default license and copyright information

=begin TML

---+ package FoswikiGitDevPlugin

You don't need to enable this plugin in Foswiki for it to be useful; most of
the code (so far) is used from the stand-alone ./extensionsdo.pl script in the
root

=cut

package Foswiki::Plugins::FoswikiGitDevPlugin;
use strict;
use warnings;

use Assert;
use Data::Dumper;
use File::Spec();
use Foswiki::Plugins::FoswikiGitDevPlugin::Extension();

#use Exporter 'import';
#our @EXPORT_OK = qw(gitCommand);

our $VERSION = '$Rev$';
our $RELEASE = '0.1.1';
our $SHORTDESCRIPTION =
  'Helper for developing Foswiki with git-repo-per-extension';
our $NO_PREFS_IN_TOPIC = 1;

# key = name, value = instance of FoswikiGitDevPlugin::RemoteSite implementation
my %remotesites;

# key = name, value = instance of FoswikiGitDevPlugin::Extension
my %extensions;
my $fetchedExtensions_dir;  # TODO Make this at least as smart as pseudo-install
my $debuglevel;

sub init {
    ( $fetchedExtensions_dir, $debuglevel ) = @_;
    my $dh;

    %remotesites = ();
    %extensions  = ();

    # Initialise a list of remotes from $Foswiki::cfg.
    while ( my ( $name, $remotesite ) =
        each %{ $Foswiki::cfg{Plugins}{FoswikiGitDevPlugin}{RemoteSites} } )
    {
        my $remoteclass =
          __PACKAGE__ . '::' . 'RemoteSiteType' . $remotesite->{type};
        require File::Spec->catfile( split( /::/, $remoteclass . '.pm' ) );
        $remotesites{$name} = $remoteclass->new( $name, %{$remotesite} );
    }

  # Round up all the extension dirs (assume they are git repos/checkouts) and
  # create ext. objects on each (which matches them up with git site & svn url).
    opendir( $dh, $fetchedExtensions_dir )
      || die("Failed to open $fetchedExtensions_dir");
    foreach my $subdir ( sort( readdir($dh) ) ) {
        my $dir = File::Spec->catdir( $fetchedExtensions_dir, $subdir );
        if ( $subdir ne '.' and $subdir ne '..' and -d $dir ) {
            my $name = pathToExtensionName($subdir);
            writeDebug( "Checking $name has $dir", 'init', 5 );
            if ($name) {
                $extensions{$name} = setupExtension( $name, $dir );
            }
            else {
                writeDebug( "$dir doesn't look like an extension name",
                    'init', 1 );
            }
        }
    }
    closedir($dh);

    #writeDebug(
    #    'remotes: '
    #      . Dumper( \%remotesites )
    #      . 'extensions: '
    #      . Dumper( \%extensions ),
    #    'init', 4
    #);

    return;
}

sub sortedValues {
    my (%hash) = @_;
    my @values;

    foreach my $key ( sort ( keys %hash ) ) {
        push( @values, $hash{$key} );
    }

    return @values;
}

sub report {
    my (%args) = @_;
    my %states =
      Foswiki::Plugins::FoswikiGitDevPlugin::Extension::getReportStates();
    my $str = join( "\t", sort( keys %states ), 'Extension' );
    my %boring;

    foreach my $extName ( sort( @{ $args{extensions} } ) ) {
        my %extStates = $extensions{$extName}->report( %{ $args{states} } );
        my $reportable;

        foreach my $state ( keys %states ) {
            if ( $extStates{$state} ) {
                $reportable = 1;
            }
            else {
                $extStates{$state} = '';
            }
        }
        if ($reportable) {
            $str .= "\n" . join( "\t", sortedValues(%extStates), $extName );
        }
        else {
            $boring{$extName} = 1;
        }
    }
    print $str
      . "\nProcessed "
      . scalar( @{ $args{extensions} } ) . ', '
      . scalar( keys %boring )
      . " filtered: "
      . join( ', ', ( sort( keys %boring ) )[ 0 .. 4 ], '..' ) . "\n";

    return;
}

sub pathToExtensionName {
    my ($path) = @_;

    $path =~ /[\/\\]?([^\.\/\\]+)(\.git)?$/;

    return $1;
}

sub listLocalExtensionNames {
    return keys %extensions;
}

sub listUniverseExtensionNames {
    my %extns = ();

    while ( my ( $remoteName, $remoteSiteObj ) = each(%remotesites) ) {
        foreach my $extName ( $remoteSiteObj->getExtensionNames() ) {
            $extns{$extName} = 1;
        }
    }

    return keys %extns;
}

# TODO: Use Foswiki::Sandbox, if we have a Foswiki::Sandbox available
sub gitCommand {
    my ( $path, $command ) = @_;

    local $ENV{PATH} = untaint( $ENV{PATH} );

    writeDebug( "path: $path, command: $command", 'gitCommand', 5 );
    my $data = `cd $path && $command`;

    return ( $data, $? >> 8 );
}

sub untaint {
    no re 'taint';
    $_[0] =~ /^(.*)$/;
    use re 'taint';
    return $1;
}

sub updateExtensions {
    my (@extensions) = @_;

    foreach my $extension (@extensions) {
        updateExtension($extension);
    }

    return;
}

sub updateExtension {
    my ($name) = @_;

    writeDebug( "Updating $name", 'updateExtension', 1 );
    if ( not $extensions{$name} ) {
        writeDebug( "$name doesn't exist locally; creating",
            'updateExtension', 1 );
        setupExtension($name);
    }
    assert_not_null( $extensions{$name} );
    $extensions{$name}->doUpdate();    # If bare, this is a NOP

    return;
}

# Set up an FoswikiGitDevPlugin::Extension object by name.
#
# It's a wrapper for ::Extension->new(). We could put more path magic here
# if we wanted to.
sub setupExtension {
    my ( $name, $fullpath ) = @_;
    my $extensionObj =
      Foswiki::Plugins::FoswikiGitDevPlugin::Extension->new( $name,
        path => $fullpath );

    $extensions{$name} = $extensionObj;

    return $extensionObj;
}

sub guessRemoteSiteByExtensionURL {
    my ($url) = @_;
    my $remoteSiteObj;

    while ( not $remoteSiteObj
        and my ( $trialname, $trialRemoteObj ) = each(%remotesites) )
    {
        if ( $trialRemoteObj->hasExtensionURL($url) ) {
            $remoteSiteObj = $trialRemoteObj;
        }
    }

    return $remoteSiteObj;
}

sub guessRemoteSiteByExtensionName {
    my ($name) = @_;
    my $remoteSiteObj;

    while ( my ( $trialname, $trialRemoteObj ) = each(%remotesites) ) {
        if ( not defined $remoteSiteObj ) {
            writeDebug( "Checking for $name in $trialname...",
                'guessRemoteSiteByExtensionName', 5 );
            if ( $trialRemoteObj->hasExtensionName($name) ) {
                $remoteSiteObj = $trialRemoteObj;
            }
        }
    }

    return $remoteSiteObj;
}

sub guessExtensionPath {
    my ($name) = @_;

    return File::Spec->catdir( $fetchedExtensions_dir, $name );
}

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    return;
}

sub writeDebug {
    my ( $message, $method, $level, $package, $refdebuglevel ) = @_;
    my @lines;

    if ( not defined $refdebuglevel ) {
        $refdebuglevel =
          (      $debuglevel
              || $Foswiki::cfg{Plugins}{FoswikiGitDevPlugin}{Debug}
              || 0 );
    }
    if ( $refdebuglevel and ( not defined $level or $level <= $refdebuglevel ) )
    {
        @lines = split( /[\r\n]+/, $message );
        foreach my $line (@lines) {
            my @packparts = split( /::/, ( $package || __PACKAGE__ ) );
            my $logline = '::'
              . $packparts[ scalar(@packparts) - 1 ]
              . "::$method():\t$line\n";

            if ( defined &Foswiki::Func::writeDebug ) {
                Foswiki::Func::writeDebug($logline);
            }
            else {    # CLI
                print STDERR $logline;
            }
        }
    }

    return;
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
