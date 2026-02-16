package Business::Service;

use strict;
use warnings;

use Mojo::IOLoop;
use Mojo::Promise;

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    return $self;
}

sub log {
    my ($self) = @_;
    return $self->{log};
}

sub query_backend_p {
    my ($self, $host, $port) = @_;

    my $promise = Mojo::Promise->new;

    # Set a timeout for the entire operation
    my $timeout = Mojo::IOLoop->timer(60 => sub {
        $promise->reject('TCP query timed out');
    });

    Mojo::IOLoop->client({ host => $host, port => $port } => sub {
        my ($loop, $err, $stream) = @_;

        # Connection error
        if ($err) {
            Mojo::IOLoop->remove($timeout);
            return $promise->reject("Connection error: $err");
        }

        my $buffer = '';
        $stream->on(read => sub {
            my ($stream, $chunk) = @_;
            $buffer .= $chunk;

            # Once we have 100 bytes, we're done.
            if (length $buffer >= 100) {
                $self->log->warn("done $buffer");
                Mojo::IOLoop->remove($timeout); # Cancel timeout
                $stream->close;
                $promise->resolve(substr($buffer, 0, 100));
            }
        });

        $stream->on(close => sub {
             Mojo::IOLoop->remove($timeout);
             # This will be a no-op if the promise has already been resolved or rejected.
             #$promise->reject('Connection closed too early');
        });
    });

    return $promise;
}

1;
