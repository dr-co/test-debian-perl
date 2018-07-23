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
    plan tests    => 16;

    use_ok 'Test::Debian';
}


system_is_debian;
package_is_installed 'dpkg';
package_isnt_installed('unknown_package_name');
package_is_installed 'dpkg | abcccc';
package_is_installed 'dddddddddddddddd | dpkg | abcccc';

my $prog = 'dpkg';
my $curr;
for (`$prog -s dpkg`) {
    $curr = $1 and last if m/^\s*Version:\s+(.+)/;
}
die "strange, can not determine `dpkg` version" unless $curr;
$curr =~ s/\S\K[a-zA-Z].+$//;
(my $prev = $curr) =~ s/([1-8])/$1 - 1/e;
(my $next = $curr) =~ s/([1-8])/$1 + 1/e;

note "Test on dpkg versions:\ncurrent $curr\nprevious $prev\nnext $next";

package_is_installed "$prog (< $curr) | $prog";
package_is_installed "$prog ( =  $curr )";
package_is_installed "$prog ( >= $curr )";
package_is_installed "$prog ( <= $curr )";
package_is_installed "$prog ( != $prev )";
package_is_installed "$prog ( != $next )";
package_is_installed "$prog ( >  $prev )";
package_is_installed "$prog ( <  $next )";
package_is_installed "$prog ( <  $next )|$prog (= $curr)";
package_is_installed "$prog ( >  $prev )|$prog";

