package Test::Debian;

use 5.008008;
use strict;
use warnings;

use Test::More;
use base 'Exporter';

our @EXPORT = qw(
    system_is_debian
    package_is_installed
    package_isnt_installed
);

our $VERSION = '0.01';

sub system_is_debian(;$) {
    my $name = shift || 'System is debian';
    Test::More->builder->ok( -r '/etc/debian_version', $name );
}


sub _pkg_list($) {
    my ($name) = @_;
    our %dpkg_list;

    unless(-x '/usr/bin/dpkg') {
        Test::More->builder->ok( 0, $name );
        diag '/usr/bin/dpkg is not found or executable';
        return 0;
    }
    unless(%dpkg_list) {
        my $pid = open my $fh, '-|', '/usr/bin/dpkg', '--get-selections';
        unless($pid) {
            my $err = $!;
            Test::More->builder->ok( 0, $name );
            diag $!;
            return 0;
        }

        %dpkg_list = map { ( @$_[0, 1] ) }
            map { [ split /\s+/, $_, 3 ] } <$fh>;
    }

    return \%dpkg_list;
}

sub package_is_installed($;$) {
    my ($pkg, $name) = @_;

    $name ||= "$pkg is installed";

    my $list = _pkg_list($name) or return 0;

    my $tb = Test::More->builder;
    return $tb->ok( 0, $name ) unless exists $list->{ $pkg };
    return $tb->cmp_ok($list->{ $pkg }, 'eq', 'install', $name);
}


sub package_isnt_installed($;$) {
    my ($pkg, $name) = @_;

    $name ||= "$pkg is not installed";

    my $list = _pkg_list($name) or return 0;

    my $tb = Test::More->builder;
    return $tb->ok( 1, $name ) unless exists $list->{ $pkg };
    return $tb->cmp_ok($list->{ $pkg }, 'ne', 'install', $name);
}


1;

=head1 NAME

Test::Debian - some tests for debian system

=head1 SYNOPSIS

  use Test::More;
  use Test::Debian;

  ok($value, 'test name');
  system_is_debian;
  package_is_installed 'dpkg';
  package_is_installed 'dpkg', 'dpkg is installed';
  package_isnt_installed 'kde-base';


=head1 DESCRIPTION

The module provides some perl tests for debian system:

=head2 system_is_debian([ $test_name ])

Passes if current OS is debian

=head2 package_is_installed($pkg_name [, $test_name ])

Passes if package is installed


=head2 package_isnt_installed($pkg_name [, $test_name ])

Passes if package isn't installed

=head1 AUTHOR

Dmitry E. Oboukhov, E<lt>unera@debian.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Dmitry E. Oboukhov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
