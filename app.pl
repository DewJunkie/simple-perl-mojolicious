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
        table_headers => [ 'ID', 'Name', 'Role', 'Status' ],
    };
    $c->render(template => 'index', %$vars);
};

get '/rows' => sub ($c) {
    # Tell Mojolicious we will render the response later
    $c->render_later;

    # Dispatch two concurrent TCP queries
    my $query1 = query_backend_p($tcp_config->{host}, $tcp_config->{port});
    my $query2 = query_backend_p($tcp_config->{host}, $tcp_config->{port});

    Mojo::Promise->all($query1, $query2)
        ->then(sub ($res1, $res2) {
            my @results = @_; # All promise results are in @_
            my @data;
            
            for my $i (0 .. $#results) {
                push @data, {
                    id => $i + 1,
                    name => "TCP Query " . ($i + 1),
                    role => 'Data Processor',
                    status => $results[$i],
                    data => $results[$i]
                };
            }

            my $html = '';
            foreach my $row (@data) {
                $html .= $c->render_to_string('row', row => $row, layout => undef);
            }
            $c->render(text => $html);
        })
        ->catch(sub ($err) {
            my $html = $c->render_to_string('row', row => {
                id => '!',
                name => 'Error',
                role => 'System',
                status => $err
            }, layout => undef);
            $c->render(text => $html, status => 500);
        });
};

# Mojolicious will automatically detect and use the public directory
app->start;
