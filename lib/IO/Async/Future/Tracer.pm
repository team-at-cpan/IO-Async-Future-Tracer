package IO::Async::Future::Tracer;
# ABSTRACT: 
use strict;
use warnings;
use 5.010;
use parent qw(IO::Async::Notifier);

our $VERSION = '0.001';

=head1 NAME

IO::Async::Future::Tracer -

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Future::Tracer;
use IO::Async::Future::Tracer::Watcher;
use IO::Async::Timer::Periodic;

=head1 METHODS

=cut
sub watcher {
	shift->{watcher} ||= Future::Debug->create_watcher(
		create => sub {
			my $class = __PACKAGE__;
			my ($ev, $f) = @_;
			say "create: " . $class->describe($f);
		},
		on_ready => sub {
			my $class = __PACKAGE__;
			my ($ev, $f) = @_;
			my $elapsed = 1000.0 * (Time::HiRes::time - $f->created);
			$f->elapsed($elapsed);
			say "ready:  " . $class->describe($f);
		},
		destroy => sub {
			my $class = __PACKAGE__;
			my ($ev, $f) = @_;
			my $elapsed = 1000.0 * (Time::HiRes::time - $f->created);
			$f->elapsed($elapsed) unless $f->is_ready;

			my $description = $class->describe($f);
			say "drop:   $description";
			unshift @{$self->old_futures}, $description;
			splice @{$self->old_futures}, 100;
		}
	);
}

sub old_futures { shift->{old_futures} ||= [] }

sub timer {
	shift->{timer} ||= IO::Async::Timer::Periodic->new(
		interval => 1,
		on_tick => sub {
			my $class = __PACKAGE__;
			say "--";
			print "All futures, from oldest to newest:\n";
			for my $f (List::UtilsBy::nsort_by { $_->created } Future::Debug->futures) {
				print "* " . $class->describe($f) . "\n";
			}
			print "Last 100 futures\n";
			for my $f (@{$self->old_futures}) {
				print "* $f\n";
			}
		}
	)
}
sub _add_to_loop {
	my ($self, $loop) = @_;
	$self->add_child($self->timer);
	$self->timer->start;
}

sub describe {
	my ($class, $f) = @_;
	my $now = Time::HiRes::time;
	my $elapsed = 1000.0 * ($now - $f->created);
	my $type = (exists $f->{subs} ? 'dependent' : 'leaf');
	sprintf "%s label [%s] elapsed %.1fms %s",
		$f->_state . ':',
		$f->label,
		$f->is_ready ? $f->elapsed : $elapsed,
		$type . (exists $f->{constructed_at} ? " " . $f->{constructed_at} : '');
}

1;

__END__

=head1 SEE ALSO

=head1 AUTHOR

Tom Molesworth <cpan@perlsite.co.uk>

=head1 LICENSE

Copyright Tom Molesworth 2014. Licensed under the same terms as Perl itself.

