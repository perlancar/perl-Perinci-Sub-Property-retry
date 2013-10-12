package Perinci::Sub::Property::retry;

use 5.010001;
use strict;
use warnings;

use Perinci::Sub::PropertyUtil qw(declare_property);

# VERSION

declare_property(
    name => 'retry',
    type => 'function',
    schema => ['any' => {default=>0, of=>[
        ['int' => {min=>0, default=>0}],
        ['hash*' => {keys=>{
            'n'     => ['int' => {min=>0, default=>0}],
            'delay' => ['int' => {min=>0, default=>0}],
            'success_statuses'   => ['regex' => {default=>'^(2..|304)$'}],
            'fatal_statuses'     => 'regex',
            'non_fatal_statuses' => 'regex',
            'fatal_messages'     => 'regex',
            'non_fatal_messages' => 'regex',
        }}],
    ]}],
    wrapper => {
        meta => {
            v       => 2,
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

            for my $k (qw/success_statuses
                          fatal_statuses non_fatal_statuses
                          fatal_messages non_fatal_messages/) {
                if (defined($v->{$k}) && ref($v->{$k}) ne 'Regexp') {
                    $v->{$k} = qr/$v->{$k}/;
                }
            }

            return unless $v->{n} > 0;

            $self->select_section('before_eval');
            $self->push_lines(
                '', 'my $_w_retries = 0;',
                'RETRY: while (1) {');
            $self->indent;

            $self->select_section('after_eval');
            if ($self->{_arg}{meta}{result_naked}) {
                $self->push_lines('if ($_w_eval_err) {');
            } else {
                $self->push_lines('if ($_w_eval_err || $_w_res->[0] !~ qr/'.
                                      $v->{success_statuses}.'/) {');
            }
            $self->indent;
            if ($v->{fatal_statuses}) {
                $self->_errif('521', '"Can\'t retry (fatal status $_w_res->[0])"',
                              '$_w_res->[0] =~ qr/'.$v->{fatal_statuses}.'/');
            }
            if ($v->{non_fatal_statuses}) {
                $self->_errif(
                    '521', '"Can\'t retry (not non-fatal status $_w_res->[0])"',
                    '$_w_res->[0] !~ qr/'.$v->{non_fatal_statuses}.'/');
            }
            if ($v->{fatal_messages}) {
                $self->_errif(
                    '521', '"Can\'t retry (fatal message: $_w_res->[1])"',
                    '$_w_res->[1] =~ qr/'.$v->{fatal_messages}.'/');
            }
            if ($v->{non_fatal_messages}) {
                $self->_errif(
                    '521', '"Can\'t retry (not non-fatal message $_w_res->[1])"',
                    '$_w_res->[1] !~ qr/'.$v->{non_fatal_messages}.'/');
            }
            $self->_errif('521', '"Maximum retries reached"',
                          '++$_w_retries > '.$v->{n});
            $self->push_lines('sleep '.int($v->{delay}).';')
                if $v->{delay};
            $self->push_lines('next RETRY;');
            $self->unindent;
            $self->push_lines('} else {');
            $self->indent;
            # return information on number of retries performed
            unless ($self->{_meta}{result_naked}) {
                $self->push_lines('if ($_w_retries) {');
                $self->push_lines($self->{indent} . '$_w_res->[3] //= {};');
                $self->push_lines($self->{indent} . '$_w_res->[3]{wrap_retries}' .
                              ' = $_w_retries;');
                $self->push_lines('}');
            }
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

Values: a hash containing these keys:

=over 4

=item * n => INT (default: 0)

Number of retries, default is 0 which means no retry.

=item * delay => INT (default: 0)

Number of seconds to wait before each retry, default is 0 which means no wait
between retries.

=item * success_statuses => REGEX (default: '^(2..|304)$')

Which status is considered success.

=item * fatal_statuses => REGEX

If set, specify that status matching this should be considered fatal and no
retry should be attempted.

=item * non_fatal_statuses => REGEX

If set, specify that status I<not> matching this should be considered fatal and
no retry should be attempted.

=item * fatal_messages => REGEX

If set, specify that message matching this should be considered fatal and no
retry should be attempted.

=item * non_fatal_messages => REGEX

If set, specify that message I<not> matching this should be considered fatal and
no retry should be attempted.

=back

Property value can also be an integer (specifying just 'n').

If function does not return enveloped result (result_naked=0), which means there
is no status returned, a function is assumed to fail only when it dies.

This property's wrapper implementation currently uses a simple loop around
the eval block.


=head1 SEE ALSO

L<Perinci>

=cut
