# See bottom of file for default license and copyright information

=begin TML

---+ package FoswikiGitDevPlugin::RemoteSiteType

A site might be a collection of repositories (supporting the repo-per-extension
model), or a single repository that supports partial checkouts (such as
svn.foswiki.org)

Anyway, this is virtual base class for remote site types.

These are only really used when extensions are fetched & init'd for the first
time, although there should be some sanity check functions to eg. connect a
manually clone'd git repo that tracks a svn repo back up as a git-svn repo.

=cut

package Foswiki::Plugins::FoswikiGitDevPlugin::RemoteSiteType;
use strict;
use warnings;

use Assert;

sub new {
    my ( $class, $name, %args ) = @_;
    my $this = bless( \%args, $class );

    $this->{type} = '<replace with type name>';
    $this->{name} = $name;
    $this->{populated} ||= 0;

    return $this;
}

sub destroy {
    my ($this) = @_;

    $this->{type}      = undef;
    $this->{name}      = undef;
    $this->{populated} = undef;

    return;
}

sub ensurePopulated {
    my ($this) = @_;

    if ( not $this->{populated} ) {
        $this->populate();
    }

    return $this->{populated};
}

sub populate {
    my ($this) = @_;

    ASSERT( 0, 'Method not implemented' );

    #populated list of extensions, etc
    #$this->{populated} = 1;

    return;
}

sub hasExtensionName {
    my ( $this, $extension ) = @_;

    $this->ensurePopulated();

    return ( exists $this->{extensions}->{$extension} ) ? 1 : 0;
}

sub hasExtensionURL {
    my ( $this, $url ) = @_;

    ASSERT( 0, 'Method not implemented' );

    #$this->ensurePopulated();
    #return $this->{extensions}->{$extension};

    return;
}

sub getExtensionNames {
    my ($this) = @_;

    return keys %{ $this->{extensions} };
}

sub initExtensionRepo {
    my ($this) = @_;

    return;
}

sub do_commands {
    my ( $this, $commands ) = @_;

    $this->writeDebug( $commands, 'do_commands', 3 );

    #local $ENV{PATH} = untaint( $ENV{PATH} );
    #`$commands`;

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
