=head1 NAME

Test::Legacy - Test.pm workalike that plays well with other Test modules


=head1 SYNOPSIS

  # use Test;
  use Test::Legacy;

  ...leave all else the same...


=head1 DESCRIPTION

Test.pm suffers from the problem of not working well with other Test
modules.  If you have a test written using Test.pm and want to use,
for example, Test::Exception you cannot.

Test::Legacy is a reimplementation of Test.pm using Test::Builder.
What this means is Test::Legacy can be used with other Test::Builder
derived modules (such as Test::More, Test::Exception, and most
everything released in the last couple years) in the same test script.

Test::Legacy strives to work as much like Test.pm as possible.  It allows
one to continue to use Test.pm while taking advantage of additional Test
modules.

=head1 DIFFERENCES

Test::Legacy does have some differences from Test.pm.  Here are the known
ones.

=over 4

=item * diagnostics

Because Test::Legacy uses Test::Builder for most of the work, failure 
diagnostics are not the same as Test.pm and are unlikely to ever be.


=item * onfail

Currently the onfail subroutine does not get passed a description of test
failures.  This is slated to be fixed in the future.

=back


=head1 AUTHOR

Michael G Schwern E<lt>schwern@pobox.comE<gt>


=head1 COPYRIGHT

Copyright 2004 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>


=head1 NOTES

This is an emulation of Test.pm 1.25.

=head1 SEE ALSO

L<Test>, L<Test::More>

=cut


package Test::Legacy;

use strict;
use vars qw($VERSION
            @ISA @EXPORT @EXPORT_OK
            $TESTERR $TESTOUT
            $ntest
           );

$VERSION        = '1.2500_01';


require Exporter;

@ISA       = qw(Exporter);
@EXPORT    = qw(plan ok skip);
@EXPORT_OK = qw($ntest $TESTOUT $TESTERR);


use Carp;


use Test::Builder;
my $TB   = Test::Builder->new;
my $Self = { todo => {}, onfail => sub {} };


tie $TESTOUT, 'Test::Legacy::FH', $TB, 'output';
tie $TESTERR, 'Test::Legacy::FH', $TB, 'failure_output';

tie $ntest, 'Test::Legacy::ntest', $TB;


sub _print { 
    local($\, $,);   # guard against -l and other things that screw with
                     # print

    print $TESTOUT @_ 
}


my %Plan_Keys = map { $_ => 1 } qw(test tests todo onfail);
sub plan {
    my %args = @_;

    croak "Test::plan(%args): odd number of arguments" if @_ & 1;

    if( my @unrecognized = grep !$Plan_Keys{$_}, keys %args ) {
        carp "Test::plan(): skipping unrecognized directive(s) @unrecognized";
    }

    $Self->{todo}   = { map { $_ => 1 } @{$args{todo}} } if $args{todo};
    $Self->{onfail} = $args{onfail}                      if $args{onfail};

    $TB->plan( tests => $args{test} || $args{tests} );

    #### Taken from Test.pm 1.25
    _print "# Running under perl version $] for $^O",
      (chr(65) eq 'A') ? "\n" : " in a non-ASCII world\n";

    _print "# Win32::BuildNumber ", &Win32::BuildNumber(), "\n"
      if defined(&Win32::BuildNumber) and defined &Win32::BuildNumber();

    _print "# MacPerl version $MacPerl::Version\n"
      if defined $MacPerl::Version;

    _print sprintf
      "# Current time local: %s\n# Current time GMT:   %s\n",
      scalar(localtime($^T)), scalar(gmtime($^T));
     ### End

    _print "# Using Test::Legacy version $VERSION\n";
}


END {
    $Self->{onfail}->() if $Self->{onfail} and _is_failing($TB);
}

sub _is_failing {
    my $tb = shift;

    return grep(!$_, $tb->summary) ? 1 : 0;
}

sub _make_faildetail {
    my $tb = shift;

    # package, repetition, result
    
}


# Taken from Test.pm 1.25
sub _to_value {
    my ($v) = @_;
    return ref $v eq 'CODE' ? $v->() : $v;
}


sub ok ($;$$) {
    my($got, $expected, $diag) = @_;
    ($got, $expected) = map _to_value($_), ($got, $expected);

    my $caller = caller;

    no strict 'refs';
    local ${ $caller.'::TODO' };
    if( $Self->{todo}{$TB->current_test + 1} ) {
        ${ $caller.'::TODO' } = ' TODO?!';
    }

    my $ok = 0;
    if( @_ == 1 ) {
        $ok = $TB->ok(@_)
    }
    elsif( defined $expected && $TB->maybe_regex($expected) ) {
        $ok = $TB->like($got, $expected);
    }
    else {
        $ok = $TB->is_eq($got, $expected);
    }

    return $ok;
}


sub skip ($;$$$) {
    my $reason = _to_value(shift);

    if( $reason ) {
        $reason = '' if $reason !~ /\D/;
        return $TB->skip($reason);
    }
    else {
        goto &ok;
    }
}


package Test::Legacy::FH;

sub TIESCALAR {
    my($class, $tb, $method) = @_;
    bless { tb => $tb, method => $method }, $_[0];
}

sub STORE {
    my $self = shift;

    my $tb   = $self->{tb};
    my $meth = $self->{method};

    return $tb->$meth(@_);
}

sub FETCH {
    my $self = shift;

    my $tb   = $self->{tb};
    my $meth = $self->{method};

    return $tb->$meth();
}


package Test::Legacy::ntest;

sub TIESCALAR {
    my($class, $tb) = @_;

    bless { tb => $tb }, $class;
}

sub FETCH {
    my $self = shift;

    return $self->{tb}->current_test;
}

sub STORE {
    my($self, $val) = @_;

    return $self->{tb}->current_test($val - 1);
}


    
