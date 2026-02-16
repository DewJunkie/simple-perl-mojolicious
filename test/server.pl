#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::IOLoop;

# Configure and get the Mojolicious logger instance
my $log = app->log;
$log->level('info');

$log->info("Non-blocking test server listening on port 1337");

# Raw TCP server using Mojo::IOLoop to handle concurrent connections
Mojo::IOLoop->server({port => 1337} => sub {
    my ($loop, $stream, $id) = @_;
    $log->info("Client $id connected");

    my $counter = 0;
    my $timer_id;
    $timer_id = Mojo::IOLoop->recurring(0.25 => sub {
        # Stop after 8 sends
        if (++$counter > 8) {
            Mojo::IOLoop->remove($timer_id);
            $stream->close;
            $log->info("Client $id disconnected after sending 8 packets.");
            return;
        }

        # Send data chunk
        $stream->write('x' x 20);
    });

    # Clean up timer if client closes connection prematurely
    $stream->on(close => sub {
        $log->info("Client $id connection closed.");
        Mojo::IOLoop->remove($timer_id) if $timer_id;
    });

    # Handle errors
    $stream->on(error => sub {
        my ($stream, $err) = @_;
        $log->error("Client $id error: $err");
        Mojo::IOLoop->remove($timer_id) if $timer_id;
    });
});

# Start the event loop if it's not already running
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;