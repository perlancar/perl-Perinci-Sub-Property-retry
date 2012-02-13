package Perinci::Sub::Wrapper::property::retry;

use 5.010;
use strict;
use warnings;

use Perinci::Util qw(declare_property);

# VERSION

declare_property(
    name => 'retry',
    type => 'function',
    schema => ['any' => {default=>0, of=>[
        ['int' => {min=>0, default=>0}],
        ['hash*' => {keys=>{
            'n'     => ['int' => {min=>0, default=>0}],
            'delay' => ['int' => {min=>0, default=>0}],
            'success_statuses' => ['regex' => {default=>'^(2..|304)$'}],
        }}],
    ]}],
    wrapper => {
        meta => {
            # very high, we want to trap errors as early as possible after eval,
            # so we can retry it.
            prio    => 0,
            convert => 1,
        },
        handler => sub {
            my ($self, %args) = @_;

            my $v    = $args{new} // $args{value};
            $v       = {n=>$v} unless ref($v) eq 'HASH';
            $v->{n}                //= 0;
            $v->{delay}            //= 0;
            $v->{success_statuses} //= qr/^(2..|304)$/;

            unless (ref($v->{success_statuses}) eq 'Regexp') {
                $v->{success_statuses} = qr/$v->{success_statuses}/;
            }

            return unless $v->{n} > 0;

            $self->select_section('before_eval');
            $self->push_lines(
                '', 'my $retries = 0;',
                'RETRY: while (1) {');
            $self->indent;

            $self->select_section('after_eval');
            if ($self->{_arg}{meta}{result_naked}) {
                $self->push_lines('if ($eval_err) {');
            } else {
                $self->push_lines('if ($eval_err || $res->[0] !~ qr/'.
                                      $v->{success_statuses}.'/) {');
            }
            $self->indent;
            $self->_errif('521', '"Maximum retries reached"',
                          '++$retries > '.$v->{n});
            $self->push_lines('sleep '.int($v->{delay}).';')
                if $v->{delay};
            $self->push_lines('next RETRY;');
            $self->unindent;
            $self->push_lines('} else {');
            $self->indent;
            $self->push_lines('last RETRY;');
            $self->unindent;
            $self->push_lines('}');
            $self->unindent;
            $self->push_lines('', '} # RETRY', '');
        },
    },
);

1;
# ABSTRACT: Specify automatic retry

=head1 SYNOPSIS

 # in function metadata
 retry => 3,

 # more detailed
 retry => {n=>3, delay=>10, success_statuses=>/^(2..|3..)$/},


=head1 DESCRIPTION

This property specifies retry behavior.

Values: a hash containing these keys 'n' (int, number of retries, default is 0
which means no retry), 'delay' (int, number of seconds to wait before each
retry, default is 0 which means no wait between retries), and 'success_statuses'
(regex, which status is considered success, default is C<^(2..|304)$>). Or it
can also be an integer (specifying just 'n').

If function does not return enveloped result (result_naked=0), which means there
is no status returned, a function is assumed to fail only when it dies.

This property's wrapper implementation currently uses a simple loop around
the eval block.


=head1 SEE ALSO

L<Perinci>

=cut
