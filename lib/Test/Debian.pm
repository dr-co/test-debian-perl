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

our $VERSION = '0.06';

my $DPKG = '/usr/bin/dpkg';

sub system_is_debian(;$) {
    my $name = shift || 'System is debian';
    Test::More->builder->ok( -r '/etc/debian_version', $name );
}


sub _pkg_list($) {
    my ($name) = @_;
    our %dpkg_list;

    unless(-x $DPKG) {
        Test::More->builder->ok( 0, $name );
        diag "$DPKG not found or executable";
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

sub package_is_installed($;@) {
    my ($pkgs, $name, $adapt) = @_;
    if (@_ >= 2) {
        ($name, $adapt) = ($adapt, $name) if ref $name eq 'CODE';
    }

    my $list = _pkg_list($name) or return 0;

    my $tb = Test::More->builder;

    $name ||= "package(s) '$pkgs' is/are installed";

    for ( split /\s*\|\s*/, $pkgs ) {
        my ($pkg, $op, $ver) = _parse_pkg($_);
        next unless $pkg;

        next unless exists $list->{ $pkg };
        next unless $list->{ $pkg } eq 'install';

        return $tb->ok( 1, $name ) unless $op;
        my $ok = _compare_versions_ok($pkg, $op, $ver, $adapt);
        return $tb->ok(1, $name) if $ok;
    }

    return $tb->ok( 0, $name );
}

sub package_isnt_installed($;$) {
    my ($pkg_spec, $name) = @_;

    $name ||= "$pkg_spec is not installed";

    my $list = _pkg_list($name) or return 0;

    my $tb = Test::More->builder;
    my ($pkg, $op, $ver) = _parse_pkg($pkg_spec);
    return $tb->ok( 0, $name) unless $pkg;

    return $tb->ok( 1, $name ) unless exists $list->{ $pkg };
    return $tb->cmp_ok($list->{ $pkg }, 'ne', 'install', $name) unless $op;

    my $res = _compare_versions_ok($pkg, $op, $ver);

    return $tb->ok( $res ? 1 : 0, $name);
}


my %ops = (
    '>'  => 'gt',
    '>=' => 'ge',
    '='  => 'eq',
    '!=' => 'ne',
    '<'  => 'lt',
    '<=' => 'le',
);

sub _parse_pkg {
    my ($str) = @_;
    $str =~ s/\s+//g;
    my ($pkg, $op, $ver) = $str =~ /^([^(]+) (?:\( ([^\d]+) ([^)]+) \))?$/x;

    my $err;
    if ($op) {
        $op = $ops{$op};
        $err = 1 unless $op && $ver =~ /^[\d._-]+/;
    }
    else {
        $err = 1 unless $pkg && length $str == length $pkg;
    }
    if ($err) {
        diag "invalid syntax for package '$_[0]'";
        return;
    }

    return ($pkg, $op, $ver);
}

sub _compare_versions_ok {
    my ($pkg, $op, $req_ver, $adapt) = @_;

    my $pid = open my $fh, '-|', $DPKG, '-s', $pkg;
    unless ($pid) {
        diag "exec: $!";
        return undef;
    }
    my @info = <$fh>;
    waitpid $pid, 0;
    if ($?) {
        diag "$DPKG error: ", $? >> 8;
        return undef;
    }
    my $inst_ver;
    for (@info) {
        $inst_ver = $1 and last if /^Version:\s+(.+)$/;
    }
    unless ($inst_ver) {
        diag "Can`t define version $pkg";
        return undef;
    }

    $inst_ver = $adapt ? $adapt->($inst_ver, $req_ver) 
                       : _adapt_version($inst_ver, $req_ver);

    my $r = system($DPKG, '--compare-versions', $inst_ver, $op, $req_ver);
    $r = $r >> 8;
    if ($r > 1) {
        diag "dpkg error: $r";
        return undef;
    }
    return $r == 0;
}

=head2 Adoptation to compare

https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-Version

[epoch:]upstream_version[-debian_revision]

                          user input       system format  
  perl                    5.18.2       =   5.18.2-2ubuntu1.1
  libapache2-mod-perl2    2.0.8        =   2.0.8+httpd24-r1449661-6ubuntu2
  pciutils                3.2.1        =   1:3.2.1-1ubuntu5.1

=cut

sub _adapt_version {
    my ($inst_ver, $req_ver) = @_;

    # epoche
    unless ($req_ver =~ /^\d+:/) {
        $inst_ver =~ s/^\d+://;
    }

    # simple user version format, 1.2.3, 4.5z
    if ($req_ver =~ /^(?:\d+:)?[\d.]+$/) {
        $inst_ver =~ s/^(?:\d+:)?[\d.]+\K.+//;
        return $inst_ver;
    }
    elsif ($req_ver =~ /^(?:\d+:)?[\d.]+[a-zA-Z]+$/) {
        $inst_ver =~ s/^(?:\d+:)?[\d.]+[a-zA-Z]+\K.+//;
        return $inst_ver;
    }

    # non simple version given. remove debian_version attempt, if need.
    if ($req_ver =~ /-[^-]+$/) {
        return $inst_ver;
    }
    else {
        $inst_ver =~ s/-[^-]+$//;
    }

    return $inst_ver;
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

=head2 package_is_installed($pkg_variant [, $test_name ])

Passes if package is installed

L<package_is_installed> understands the following syntax:

    package1 | package2
    package1 (< 1.23) | package2 (> 1.3)


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
