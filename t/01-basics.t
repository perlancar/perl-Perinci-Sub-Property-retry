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
my $n;

# dies n times before succeeding
$sub = sub {my %args=@_; do{$n++; die} if $n < $args{n}; [200,"OK"]; };
$meta = {v=>1.1, args=>{n=>{}}};

# test param: n

$n=0;
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

# return status code s1 and message m1 for n times, then s2/m2. remember number
# of retries.
$sub = sub {
    my %args=@_;
    do {$n++; return [$args{s1}, $args{m1} // "m1"]} if $n < $args{n};
    return [$args{s2}, $args{m2} // "m2"];
};
$meta = {v=>1.1, args=>{s1=>{}, n=>{}, s2=>{}}};

# test param: success_statuses

$n=0;
test_wrap(
    name        => 'success_statuses #1',
    wrap_args   => {sub => $sub, meta => $meta,
                    convert=>{retry=>{n=>2, success_statuses=>qr/^311$/}}},
    wrap_status => 200,
    call_argsr  => [s1=>311, n=>2, s2=>200],
    call_status => 311,
    posttest    => sub {
        is($n, 1, 'n');
    },
);

$n=0;
test_wrap(
    name        => 'success_statuses #2',
    wrap_args   => {sub => $sub, meta => $meta,
                    convert=>{retry=>{n=>2, success_statuses=>qr/^200$/}}},
    wrap_status => 200,
    call_argsr  => [s1=>311, n=>2, s2=>200],
    call_status => 200,
    posttest    => sub {
        is($n, 2, 'n');
    },
);

# test param: fatal_statuses

$n=0;
test_wrap(
    name        => 'fatal_statuses',
    wrap_args   => {sub => $sub, meta => $meta,
                    convert=>{retry=>{n=>2, fatal_statuses=>qr/^311$/}}},
    wrap_status => 200,
    call_argsr  => [s1=>311, n=>2, s2=>200],
    call_status => 521,
    posttest    => sub {
        is($n, 1, 'n');
    },
);

# test param: non_fatal_statuses

$n=0;
test_wrap(
    name        => 'non_fatal_statuses #1',
    wrap_args   => {sub => $sub, meta => $meta,
                    convert=>{retry=>{n=>2, non_fatal_statuses=>qr/^311$/}}},
    wrap_status => 200,
    call_argsr  => [s1=>311, n=>2, s2=>200],
    call_status => 200,
    posttest    => sub {
        is($n, 2, 'n');
    },
);

$n=0;
test_wrap(
    name        => 'non_fatal_statuses #2',
    wrap_args   => {sub => $sub, meta => $meta,
                    convert=>{retry=>{n=>2, non_fatal_statuses=>qr/^312$/}}},
    wrap_status => 200,
    call_argsr  => [s1=>311, n=>2, s2=>200],
    call_status => 521,
    posttest    => sub {
        is($n, 1, 'n');
    },
);

# test param: fatal_messages

$n=0;
test_wrap(
    name        => 'fatal_messages',
    wrap_args   => {sub => $sub, meta => $meta,
                    convert=>{retry=>{n=>2, fatal_messages=>qr/^m1$/}}},
    wrap_status => 200,
    call_argsr  => [s1=>311, n=>2, s2=>200],
    call_status => 521,
    posttest    => sub {
        is($n, 1, 'n');
    },
);

# test param: non_fatal_messages

$n=0;
test_wrap(
    name        => 'non_fatal_messages #1',
    wrap_args   => {sub => $sub, meta => $meta,
                    convert=>{retry=>{n=>2, non_fatal_messages=>qr/^m1$/}}},
    wrap_status => 200,
    call_argsr  => [s1=>311, n=>2, s2=>200],
    call_status => 200,
    posttest    => sub {
        is($n, 2, 'n');
    },
);

$n=0;
test_wrap(
    name        => 'non_fatal_messages #2',
    wrap_args   => {sub => $sub, meta => $meta,
                    convert=>{retry=>{n=>2, non_fatal_messages=>qr/^m3$/}}},
    wrap_status => 200,
    call_argsr  => [s1=>311, n=>2, s2=>200],
    call_status => 521,
    posttest    => sub {
        is($n, 1, 'n');
    },
);

# test param: delay


{
    $n=0;
    my $t0=time();
    test_wrap(
        name        => 'delay',
        wrap_args   => {sub => $sub, meta => $meta,
                        convert=>{retry=>{n=>2, delay=>2}}},
        wrap_status => 200,
        call_argsr  => [s1=>311, n=>1, s2=>200],
        call_status => 200,
        posttest    => sub {
            is($n, 1, 'n');
            my $t1 = time();
            #diag $t1-$t0;
            ok($t1-$t0 > 1, '>1 secs elapsed');
        },
    );
}

done_testing();
