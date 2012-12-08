#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../lib);

BEGIN {
    use Test::More;

    plan skip_all => 'Current system is not Debian'
        unless -r '/etc/debian_version';
    plan tests    => 6;

    use_ok 'Test::Debian';
}


system_is_debian;
package_is_installed 'dpkg';
package_isnt_installed('unknown_package_name');
package_is_installed 'dpkg|abcccc';
package_is_installed 'dddddddddddddddd|dpkg|abcccc';
