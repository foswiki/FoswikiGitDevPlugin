# See bottom of file for default license and copyright information

=begin TML

---+ package FoswikiGitDevPlugin::SvnRepo

=cut

package Foswiki::Contrib::FoswikiGitDevPlugin::SvnSite;
use strict;
use warnings;

use SVN::Client;
use Foswiki::Plugins::FoswikiGitDevPlugin::Site;
our @ISA = qw( Foswiki::Plugins::FoswikiGitDevPlugin::Site );

sub new {
    my ( $class, %args ) = @_;
    my $this = bless( \%args, $class );

    $this->{extensions} = undef;
    $this->{ctx}        = undef;
    $this->{populated}  = undef;

    #    $this->{branches}   = undef;
    #    $this->{type}       = 'svn';
    #    $this->{url}        = undef;

    return $this;
}

sub ensurePopulated {
    my ($this) = @_;

    if ( not $this->{populated} ) {
        $this->populate();
    }

    return;
}

sub populate {
    my ($this) = @_;

    if ( not $this->{ctx} ) {
        $this->{ctx} = SVN::Client->new();
    }
    while ( my ( $branch, $branchdata ) = each( %{ $this->{branches} } ) ) {

        # If it contains a path key, then assume we need to populate the list
        # of extensions this branch contains via SVN listing
        if ( $branchdata->{path} ) {
            writeDebug( "Listing $svninfo->{url}/$branchdata->{path}",
                'populate' );
            @extensions_in_branch =
              keys %{ $this->{ctx}
                  ->ls( $this->{url} . '/' . $branchdata->{path}, 'HEAD', 0 ) };
            foreach my $ext (@extensions_in_branch) {
                if ( $ext ne 't2fos.sh' ) {
                    $this->_addExtensionBranch( $ext, $branch,
                        $branchdata->{path} . '/' . $ext );
                }
            }
        }

        # Else, we have a manual branch+path mapping for a given extension
        else {
            while ( my ( $ext, $path ) = each %{$branchdata} ) {
                $this->_addExtensionBranch( $ext, $branch, $path );
            }
        }
    }
    $this->{populated} = 1;

    return;
}

sub getExtension {
    my ( $this, $extension ) = @_;

    $this->ensurePopulated();

    return $this->{extensions}->{$extension};
}

sub _addExtensionBranch {
    my ( $this, $extension, $branch, $path ) = @_;
    my $extObj = $this->extensions->{$extension};

    if ( not $extObj ) {
        $this->{extensions}->{$extension} =
          Foswiki::Contrib::FoswikiGitDevPlugin::Extension->new($extension);
        $extObj = $this->{extensions}->{$extension};
    }
    $extObj->addSvnBranch( $this, $branch, $path );

    return $extObj;
}

sub listExtensionNames {
    my ($this) = @_;

    return keys %{ $this->{extensions} };
}

sub setupGitRepo {
    my ( $this, $extension, $repoDir ) = @_;
    my $success = 0;
    my $extObj  = $this->getExtension($extension);
    my $trunkPath;

    if ($extObj) {
        $trunkPath = $extObj->getSvnBranchPath('trunk');
        while ( my ( $branch, $branchdata ) =
            each( %{ $extObj->getSvnBranches() } ) )
        {
            if ( $branch ne 'trunk' ) {
                writeDebug(
"Aliasing refs/remotes/$branchdata->{path} as origin/$branch",
                    'setupGitRepo'
                );
                do_commands(<<"HERE");
cd $repoDir
git update-ref refs/remotes/$branchdata->{path} origin/$branch
HERE
            }
        }
        writeDebug(
            "Initialising $this->{url}/$trunkPath as trunk & origin/master",
            'setupGitRepo' );
        do_commands(<<"HERE");
cd $repoDir
git update-ref refs/remotes/trunk origin/master
git svn init $this->{url} -T $trunkPath
HERE
        $success = 1;
    }
    else {
        writeDebug( "Couldn't find $extension at $this->{url} in any branch",
            'setupGitRepo' );
    }

    return $success;
}

sub do_commands {
    my ($commands) = @_;

    writeDebug( $commands, 'do_commands' );

    #local $ENV{PATH} = untaint( $ENV{PATH} );
    #`$commands`;

    return;
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
