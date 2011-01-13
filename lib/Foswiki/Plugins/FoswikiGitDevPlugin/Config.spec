# ---+ Extensions
# ---++ FoswikiGitDevPlugin
# ---+++ Sites
# ---++++ foswikisvn
# **PERL**
# Layout of branches & extensions within the official svn repository
#$Foswiki::cfg{Plugins}{FoswikiGitDevPlugin}{RemoteSites}{foswikisvn} = {
#    type     => 'SVN',
#    url      => 'http://svn.foswiki.org',
#    branches => {
#        pharvey =>
#          { WikiDrawPlugin => 'branches/scratch/pharvey/WikiDrawPlugin' },
#        ItaloValcy => {
#            ImageGalleryPlugin =>
#              'branches/scratch/ItaloValcy/ImageGalleryPlugin_5x10'
#        },
#        'foswikidotorg' => { path => 'branches/foswiki.org' },
#        'Release01x00'  => { path => 'branches/Release01x00' },
#        'Release01x01'  => { path => 'branches/Release01x01' },
#        'trunk'         => { path => 'trunk' }
#    }
#};

# ---+ Extensions
# ---++ FoswikiGitDevPlugin
# ---+++ Sites
# ---++++ foswikigitsvn
# **PERL**
$Foswiki::cfg{Plugins}{FoswikiGitDevPlugin}{RemoteSites}{foswikigitsvn} = {
    type    => 'GitTrackingSVN',
    url     => 'git://github.com/foswiki',
    exclude => [qw(foswiki)],
    track   => 'foswikisvn',
    bare    => 1
};

# ---+ Extensions
# ---++ FoswikiGitDevPlugin
# ---+++ Debug
# **NUMBER**
# 0 = no debug log output, 1 = some, 2 = lots, 3 = maximum, 4 = insane
$Foswiki::cfg{Plugins}{FoswikiGitDevPlugin}{Debug} = 0;

1;
