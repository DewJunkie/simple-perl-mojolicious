package Controller::Rows;

use strict;
use warnings;

use Mojo::Promise;

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    return $self;
}

sub business_service {
    my ($self) = @_;
    return $self->{business_service};
}

sub tcp_config {
    my ($self) = @_;
    return $self->{tcp_config};
}

sub handler {
    my ($self, $c) = @_;
    # Tell Mojolicious we will render the response later
    $c->render_later;

    my $service = $self->business_service;
    my $tcp_config = $self->tcp_config;

    # Dispatch two concurrent TCP queries
    my @promises;
    for(my $i = 0; $i < 20; $i++) {
        push @promises, $service->query_backend_p($tcp_config->{host}, $tcp_config->{port});
    }

    Mojo::Promise->all(@promises)
        ->then(sub {
            my @results = @_;
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
        ->catch(sub {
            my ($err) = @_;
            # Handle the case where the error is also an array ref
            my $error_message = ref $err eq 'ARRAY' ? $err->[0] : $err;
            my $error_record = [
                { label => 'Error', value => $error_message }
            ];
            my $html = $c->render_to_string('row', record => $error_record, layout => undef);
            $c->render(text => $html, status => 500);
        });
}

1;
