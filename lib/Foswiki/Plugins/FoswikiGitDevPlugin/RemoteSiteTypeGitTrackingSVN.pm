# See bottom of file for default license and copyright information

=begin TML

---+ package FoswikiGitDevPlugin::Site

A site might be a collection of repositories (supporting the repo-per-extension
model), or a single repository that supports partial checkouts (such as
svn.foswiki.org)

See the destroy() method

=cut

package Foswiki::Plugins::FoswikiGitDevPlugin::Site;
use strict;
use warnings;

sub new {
    my ( $class, $name, $type, %args ) = @_;
    my $this = bless( \%args, $class );

    $this->{type} = $type;
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

    assert( 0, "Method not implemented" );

    #populated list of extensions, etc
    #$this->{populated} = 1;

    return;
}

sub hasExtension {
    my ( $this, $extension ) = @_;

    assert( 0, "Method not implemented" );

    #$this->ensurePopulated();
    #return $this->{extensions}->{$extension};

    return;
}

sub listExtensions {
    my ($this) = @_;

    return keys %{ $this->{extensions} };
}

sub listExtensionBranches {
    my ( $this, $extension ) = @_;

    assert( 0, "Method not implemented" );

    return;
}

sub do_commands {
    my ($commands) = @_;

    writeDebug( $commands, 'do_commands' );

    #local $ENV{PATH} = untaint( $ENV{PATH} );
    #`$commands`;

    return;
}

sub writeDebug {
    my ( $this, $message, $method ) = @_;

    return Foswiki::Plugins::FoswikiGitDevPlugin::writeDebug( $message, $method,
        __PACKAGE__ );
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
