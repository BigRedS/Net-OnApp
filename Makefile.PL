use 5.010000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Net::OnApp',
    VERSION_FROM      => 'lib/Net/OnApp.pm', # finds $VERSION
    PREREQ_PM         => {
	    JSON	=> 2.53
	    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Net/OnApp.pm', # retrieve abstract from module
       AUTHOR         => 'Avi Greenbury <bigreds@cpan.org>') : ()),
);
