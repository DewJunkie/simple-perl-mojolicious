#!/usr/bin/env perl
use Mojolicious::Lite -signatures;
use Path::Tiny;
use TOML::Tiny 'from_toml';

# --- CONFIGURATION ---
my $config = from_toml(path('config.toml')->slurp_utf8);
my $tcp_config = $config->{tcp_service};
# --- END CONFIGURATION ---

use Mojo::IOLoop;
use Mojo::Promise;

# This function performs a non-blocking TCP query and returns a promise.
sub query_backend_p {
    my ($host, $port) = @_;

    my $promise = Mojo::Promise->new;

    # Set a timeout for the entire operation
    my $timeout = Mojo::IOLoop->timer(5 => sub {
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
                warn "done $buffer";
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

get '/' => sub ( $c ) {
    my $vars = {
        title => 'Modern Perl Layout',
        tabs => [
            { name => 'Home', link => '/', is_active => 1 },
            { name => 'Products', link => 'products', is_active => 0 },
            { name => 'About', link => 'about', is_active => 0 },
            { name => 'Contact', link => 'contact', is_active => 0 },
        ],
    };
    $c->render(template => 'index', %$vars);
};

get '/rows' => sub ($c) {
    # Tell Mojolicious we will render the response later
    $c->render_later;

    # Dispatch two concurrent TCP queries
    my @promises;
    push @promises, query_backend_p($tcp_config->{host}, $tcp_config->{port});
    push @promises, query_backend_p($tcp_config->{host}, $tcp_config->{port});
    push @promises, query_backend_p($tcp_config->{host}, $tcp_config->{port});

    Mojo::Promise->all(@promises)
        ->then(sub {
            my @results = @_; # All promise results are in @_
            my @records;

            my $i = 0;
            my $html = '';
            foreach my $result (@results) {
                my $record = [];
                if ($i % 2 == 0) {
                    # First record
                    $record = [
                        { label => 'Record ID', value => 'A-1' },
                        { label => 'Source',    value => 'TCP Query 1' },
                        { label => 'Payload',   value => $results[0]->[0] },
                        { label => 'Length',    value => length($results[0]->[0]) . ' bytes' }
                    ];
                } else {
                    # Second record (with a different structure)
                    $record =[ 
                        { label => 'Record ID', value => 'B-2' },
                        { label => 'Source',    value => 'TCP Query 2' },
                        { label => 'Payload',   value => $results[1]->[0] },
                        { label => 'Timestamp', value => time() },
                        { label => 'Status',    value => 'Processed' }
                    ];
                }
                $html .= $c->render_to_string('row', record => $record, layout => undef);
                $i = $i + 1;
            }
            $c->render(text => $html);
        })
        ->catch(sub ($err) {
            # Handle the case where the error is also an array ref
            my $error_message = ref $err eq 'ARRAY' ? $err->[0] : $err;
            my $error_record = [
                { label => 'Error', value => $error_message }
            ];
            my $html = $c->render_to_string('row', record => $error_record, layout => undef);
            $c->render(text => $html, status => 500);
        });
};

# Mojolicious will automatically detect and use the public directory
app->start;
