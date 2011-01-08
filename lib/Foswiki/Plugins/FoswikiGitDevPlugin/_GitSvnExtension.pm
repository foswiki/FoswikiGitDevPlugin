# See bottom of file for default license and copyright information

=begin TML

---+ package FoswikiGitDevPlugin::GitRepo

=cut

package Foswiki::Plugins::FoswikiGitDevPlugin::GitSvnExtension;
use strict;
use warnings;

use Foswiki::Plugins::FoswikiGitDevPlugin::Extension;
our @ISA = qw( Foswiki::Plugins::FoswikiGitDevPlugin::Extension );

sub new {
    my ( $class, $extension, $path, %args ) = @_;
    my $this = bless( \%args || {}, $class );

    $this->{type} ||= 'git';

    #    $this->{url} = undef;
    #    $this->{svnreponame} = undef;
    #    $this->{bare} = undef;
    assert_not_null( $this->{repopath} );
    if ( not defined $this->{bare} ) {
        if ( $this->{repopath} =~ /\.git$/ ) {
            $this->{bare} = 1;
        }
    }
    if ( not defined $this->{url} ) {
        $this->{url} = $this->getFetchUrl();
    }
    if ( not defined $this->{svnreponame} ) {
        $this->{svnreponame} =
          Foswiki::Plugins::FoswikiGitDevPlugin::guessSvnRepoName($extension);
    }
    if ( not -d $repopath ) {
        if ( $this->{bare} ) {
            do_commands(<<"HERE");
git init $repopath --bare
HERE
        }
        else {
            do_commands(<<"HERE");
git init $repopath
HERE
        }
    }

    return $this;
}

sub _getFetchUrl {
    my ($repopath) = @_;
    my $url;
    my @lines = split( /[\r\n]+/, do_commands(<<"HERE") );
cd $repopath
git remote show origin
HERE

    foreach my $line (@lines) {
        if ( $line =~ /\s*Fetch\s*URL:\s*(.*?)$/i ) {
            $url = $1;
        }
    }

    return $url;
}

sub getFetchUrl {
    my ( $this, $repopath ) = @_;

    return _getFetchUrl( $repopath || $this->{repopath} );
}

sub doFetch {
    my ($this) = @_;

    do_commands(<<"HERE");
cd $this->{repopath}
git svn fetch --all
HERE

    return;
}

sub doRebase {
    my ($this) = @_;

    do_commands(<<"HERE");
cd $this->{repopath}
git svn rebase
HERE

    return;
}

sub isBare {
    my ($this) = @_;

    return $this->{bare};
}

sub do_commands {
    my ($commands) = @_;

    print $commands . "\n";
    local $ENV{PATH} = untaint( $ENV{PATH} );

    return `$commands`;
}

sub writeDebug {
    my ( $message, $method ) = @_;

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
