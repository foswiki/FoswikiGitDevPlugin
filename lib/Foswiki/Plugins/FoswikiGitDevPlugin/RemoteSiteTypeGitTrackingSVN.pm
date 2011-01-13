# See bottom of file for default license and copyright information

=begin TML

---+ package FoswikiGitDevPlugin::RemoteSiteTypeGitTrackingSVN

A site might be a collection of repositories (supporting the repo-per-extension
model), or a single repository that supports partial checkouts (such as
svn.foswiki.org)

See the destroy() method

=cut

package Foswiki::Plugins::FoswikiGitDevPlugin::RemoteSiteTypeGitTrackingSVN;
use strict;
use warnings;

use Assert;
use Data::Dumper;
use Net::GitHub::V2::Repositories();

use Foswiki::Plugins::FoswikiGitDevPlugin::RemoteSiteType();
our @ISA = qw( Foswiki::Plugins::FoswikiGitDevPlugin::RemoteSiteType );

sub new {
    my ( $class, $name, %args ) = @_;
    my $this = bless( \%args, $class );

    $this->{type} = 'GitTrackingSVN';
    $this->{name} = $name;
    $this->{populated} ||= 0;
    $this->{extensions} = {};
    $this->{excluded}   = {};

    #$this->writeDebug( 'Built ' . __PACKAGE__ . ' with: ' . Dumper($this),
    #    'new', 4 );

    return $this;
}

sub destroy {
    my ($this) = @_;

    $this->{type}       = undef;
    $this->{name}       = undef;
    $this->{extensions} = undef;
    $this->{excluded}   = undef;
    $this->{populated}  = undef;

    return;
}

sub populateFromGithub {
    my ( $this, $owner, $repo ) = @_;
    my %excluded;    # list to exclude
    $repo ||= 'foswiki';

    # setup the excluded extensions
    foreach my $exclude ( @{ $this->{exclude} } ) {
        $excluded{$exclude} = 1;
    }
    $this->writeDebug( "Excluding: " . join( ', ', keys %excluded ),
        'populateFromGithub', 3 );
    $this->writeDebug( "Listing github repos from $owner...",
        'populateFromGithub', 2 );
    $this->{githubrepo} = Net::GitHub::V2::Repositories->new(
        owner   => $owner,
        version => 2,
        repo    => $repo
    );
    foreach my $githubThing ( sort( @{ $this->{githubrepo}->list() } ) ) {
        if ( not $excluded{ $githubThing->{name} } ) {
            $this->{extensions}->{ $githubThing->{name} } = {
                githubdata => $githubThing,
                url        => "$this->{url}/$githubThing->{name}"
            };
        }
        else {
            $this->{excluded}->{ $githubThing->{name} } = 1;
        }
    }
    $this->writeDebug(
        'Found '
          . scalar( keys %{ $this->{extensions} } ) . ': '
          . join( ', ', sort( keys %{ $this->{extensions} } ) ),
        'populateFromGithub', 4
    );
    if ( scalar( keys %{ $this->{excluded} } ) ) {
        $this->writeDebug(
            'Ignored/excluded '
              . scalar( keys %{ $this->{excluded} } ) . ': '
              . join( ', ', sort( keys %{ $this->{excluded} } ) ),
            'populateFromGithub', 4
        );
    }

    return;
}

sub populate {
    my ($this) = @_;

    ASSERT( $this->{url} );
    if ( $this->{url} =~
        /^(\w+:\/\/([^\@]+\@)?)?\bgithub\.com\/([^\/]*)(\/([^\/]+))?/i )
    {
        $this->populateFromGithub( $3, $5 );
    }
    else {
        ASSERT( 0,
            'Sorry, only know how to list github repositories so far...' );
    }

    $this->{populated} = 1;

    return;
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
