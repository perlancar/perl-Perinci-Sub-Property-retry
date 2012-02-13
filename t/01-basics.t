#!perl

use 5.010;
use strict;
use warnings;

use List::Util qw(sum);
use Perinci::Sub::Wrapper qw(wrap_sub);
use Test::More 0.96;
use Test::Perinci::Sub::Wrapper qw(test_wrap);
use Perinci::Sub::property::retry;

my ($sub, $meta);
my $n = 0;

# dies n times before succeeding
$sub = sub {my %args=@_; do{$n++; die} if $n < $args{n}; [200,"OK"]; };
$meta = {v=>1.1, args=>{n=>{}}};
test_wrap(
    name => 'no retry, dies',
    wrap_args => {sub => $sub, meta => $meta},
    wrap_status => 200,
    call_argsr => [n=>1],
    call_status => 500,
);
$n=0;
test_wrap(
    name => 'retry=1, succeed',
    wrap_args => {sub => $sub, meta => $meta, convert=>{retry=>1}},
    wrap_status => 200,
    call_argsr => [n=>1],
    call_status => 200,
);
$n=0;
test_wrap(
    name => 'retry=1, max retries reached',
    wrap_args => {sub => $sub, meta => $meta, convert=>{retry=>1}},
    wrap_status => 200,
    call_argsr => [n=>2],
    call_status => 521,
);

# XXX instead of dieing, return an error status instead

# XXX test success_statuses

# XXX test delay

done_testing();
