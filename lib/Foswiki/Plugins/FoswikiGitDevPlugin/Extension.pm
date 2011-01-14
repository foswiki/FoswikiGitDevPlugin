# See bottom of file for default license and copyright information

=begin TML

---+ package FoswikiGitDevPlugin::Extension

An object to interact with the (git) repo sitting at a particular path which is
also the root of an extension, Eg. /path/to/MyPlugin/

Must have a name.

If the extension doesn't exist on the filesystem, then consult the remote
sites to see if any of them know it; ask the first match to initialise it.

If the extension does exist on the filesystem, then all that needs to be done
is:
   * Check if it's a git repo
   * Check if it's a bare git repo (on demand)

=cut

package Foswiki::Plugins::FoswikiGitDevPlugin::Extension;
use strict;
use warnings;

use Assert;
use Data::Dumper;
use File::Path();
use Foswiki::Plugins::FoswikiGitDevPlugin();

#use Foswiki::Plugins::FoswikiGitDevPlugin 'Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand';

sub new {
    my ( $class, $name, %args ) = @_;
    my $this = bless( \%args, $class );

    ASSERT( defined $name );
    $this->{name} = $name;
    if ( not $this->{path} ) {
        $this->{path} =
          Foswiki::Plugins::FoswikiGitDevPlugin::guessExtensionPath($name);
    }
    if ( not -d $this->{path} or not $this->isGitRepo() ) {
        $this->writeDebug(
            "$this->{name} doesn't eixst or invalid git repo at $this->{path}",
            'new', 1
        );
    }
    else {
        $this->writeDebug( "$this->{name} exists already with valid git repo",
            'new', 2 );
    }

    return $this;
}

sub destroy {
    my ($this) = @_;

    $this->{name}      = undef;
    $this->{path}      = undef;
    $this->{bare}      = undef;
    $this->{originurl} = undef;
    $this->{svnurl}    = undef;

    return;
}

# $remoteSiteObj is optional; if omitted, scan configured sites and select the
# first one which knows this extension by name
sub initRepo {
    my ( $this, $remoteSiteObj ) = @_;
    my $mkpath_success = eval {
        if ( not -d $this->{path} )
        {
            File::Path->make_path( $this->{path} );
        }
        1;
    };
    my $foundRemote;

    ASSERT($mkpath_success);
    $this->writeDebug( "Making $this->{name}...", 'initRepo', 5 );
    if ( not defined $remoteSiteObj ) {
        $remoteSiteObj =
          Foswiki::Plugins::FoswikiGitDevPlugin::guessRemoteSiteByExtensionName(
            $this->{name} );
    }
    if ( defined $remoteSiteObj ) {
        $remoteSiteObj->initExtensionRepo($this);
        $foundRemote = 1;
    }

    return $foundRemote;
}

sub getSVNURL {
    my ($this) = @_;

    if ( not defined $this->{svnurl} ) {
        ( $this->{svnurl} ) =
          Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand( $this->{path},
            'git config --get-all svn-remote.svn.url' );
    }

    return $this->{svnurl};
}

sub getOriginURL {
    my ($this) = @_;

    if ( not defined $this->{originurl} ) {
        ( $this->{originurl} ) =
          Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand( $this->{path},
            'git config --get remote.origin.url' );
    }

    return $this->{originurl};
}

sub isGitRepo {
    my ($this) = @_;
    my ( $data, $status ) =
      Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand( $this->{path},
        'git status --porcelain' );

    #    $this->writeDebug( "Data: $data, Status: $status", 'isGitRepo', 4 );
    if ( $status == 0 ) {
        $status = 1;
    }
    else {
        $status = 0;
    }

    return $status;
}

sub isBare {
    my ($this) = @_;
    my $bare;

    if ( not defined $this->{bare} ) {
        ($bare) =
          Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand( $this->{path},
            'git config --get core.bare' );
        if ( $bare =~ /true/i ) {
            $this->{bare} = 1;
        }
        else {
            $this->{bare} = 0;
        }
    }

    return $this->{bare};
}

sub getReportStates {
    return ( M => 1, A => 1, D => 1, R => 1, C => 1, U => 1, '?' => 1 );
}

sub getSpecialReportStates {
    return ( dirty => 'MADRCU' );
}

sub report {
    my ( $this, %reportStates ) = @_;
    my ($statusoutput) =
      Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand( $this->{path},
        'git status --porcelain' );
    my %states;
    my $reportable    = 0;
    my %allowedStates = $this->getReportStates();

    if ( not scalar( keys %reportStates ) ) {
        %reportStates = %allowedStates;
    }

#	$this->writeDebug("Reporting " . join(', ', keys %reportStates), 'report', 4);

    foreach my $line ( split( /\n/, $statusoutput ) ) {
        my ( $x, $y ) = ( $line =~ /^(.)(.)/ );

        if ( $reportStates{$x} or $reportStates{$y} ) {
            $reportable = 1;
        }
        if ( $allowedStates{$x} ) {
            $states{$x} += 1;
        }
        if ( $allowedStates{$y} ) {
            $states{$y} += 1;
        }
    }

    #	$this->writeDebug("Got " . join(', ', sort(keys %states)), 'report', 4);

    return $reportable ? %states : ();
}

sub fetch {
    my ($this) = @_;
    my $status;

    if ( $this->getSVNURL() ) {
        ( undef, $status ) =
          Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand( $this->{path},
            'git svn fetch --all' );
    }
    elsif ( $this->getOriginURL() ) {
        ( undef, $status ) =
          Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand( $this->{path},
            'git fetch --all' );
    }
    if ( not defined $status or $status != 0 ) {
        $status = 0;
        $this->writeDebug( "$this->{name} failed fetch", 'fetch', 1 );
    }
    else {
        $status = 1;
        $this->writeDebug( "$this->{name} fetch successful", 'fetch', 2 );
    }

    return $status;
}

sub update {
    my ($this) = @_;
    my $status;

    if ( $this->getSVNURL() ) {
        ( undef, $status ) =
          Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand( $this->{path},
            'git svn rebase' );
    }
    elsif ( $this->getOriginURL() ) {
        ( undef, $status ) =
          Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand( $this->{path},
            'git pull --ff-only' );
    }
    if ( not defined $status or $status != 0 ) {
        $status = 0;
        $this->writeDebug( "$this->{name} failed update", 'update', 1 );
    }
    else {
        $status = 1;
        $this->writeDebug( "$this->{name} update successful", 'update', 2 );
    }

    return $status;
}

sub checkout {
    my ( $this, $ref ) = @_;
    my $status;

    ( undef, $status ) = Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand(
        $this->{path},
        'git checkout %REF|S%',
        REF => $ref
    );
    if ( not defined $status or $status != 0 ) {
        $status = 0;
        $this->writeDebug( "$this->{name} failed checkout '$ref'",
            'checkout', 1 );
    }
    else {
        $status = 1;
        $this->writeDebug( "$this->{name} checkout '$ref' successful",
            'checkout', 2 );
    }

    return $status;
}

sub docommand {
    my ( $this, $command ) = @_;
    my $status;

    ( undef, $status ) =
      Foswiki::Plugins::FoswikiGitDevPlugin::gitCommand( $this->{path},
        $command );
    if ( not defined $status or $status != 0 ) {
        $status = 0;
        $this->writeDebug( "$this->{name} failed command '$command'",
            'command', 1 );
    }
    else {
        $status = 1;
        $this->writeDebug( "$this->{name} command '$command' successful",
            'command', 2 );
    }

    return $status;
}

sub writeDebug {
    my ( $this, $message, $method, $level ) = @_;

    return Foswiki::Plugins::FoswikiGitDevPlugin::writeDebug( $message, $method,
        $level, __PACKAGE__ );
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
